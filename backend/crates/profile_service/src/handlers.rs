use std::fmt::Write as _;

use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
};
use sqlx::PgPool;
use time::Time;
use uuid::Uuid;

use crate::models::{
    DoctorProfile, DoctorScheduleSlot, PatientProfile, ProfileQuery, UpdateDoctorProfileReq,
};

struct DoctorRecord {
    user_id: Uuid,
    email: Option<String>,
    first_name: String,
    last_name: String,
    phone: String,
    citizen_id: String,
    mln: Option<String>,
    department: Option<String>,
    position: Option<String>,
}

pub async fn get_patient_profile(
    State(pool): State<PgPool>,
    Query(query): Query<ProfileQuery>,
) -> Result<Json<PatientProfile>, (StatusCode, String)> {
    let record = sqlx::query!(
        r#"
        SELECT
            u.user_id,
            u.email,
            u.first_name,
            u.last_name,
            u.phone,
            u.citizen_id,
            pp.hn as "hn?",
            phi.age as "age?",
            phi.height_cm::float as "height_cm?",
            phi.weight_kg::float as "weight_kg?",
            phi.medical_conditions,
            phi.drug_allergies
        FROM users u
        LEFT JOIN patient_profile pp ON pp.user_id = u.user_id
        LEFT JOIN patient_health_info phi ON phi.patient_id = u.user_id
        WHERE u.email = $1
        "#,
        query.email
    )
    .fetch_optional(&pool)
    .await
    .map_err(internal_error)?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "Patient not found".to_string()))?;

    let profile = PatientProfile {
        user_id: record.user_id,
        email: record.email.unwrap_or_default(),
        first_name: record.first_name,
        last_name: record.last_name,
        phone: record.phone,
        citizen_id: record.citizen_id,
        hn: record.hn,
        age: record.age,
        height_cm: record.height_cm,
        weight_kg: record.weight_kg,
        medical_conditions: record.medical_conditions,
        drug_allergies: record.drug_allergies,
    };

    Ok(Json(profile))
}

pub async fn get_doctor_profile(
    State(pool): State<PgPool>,
    Query(query): Query<ProfileQuery>,
) -> Result<Json<DoctorProfile>, (StatusCode, String)> {
    let profile = fetch_doctor_profile_by_email(&pool, &query.email).await?;
    Ok(Json(profile))
}

pub async fn update_doctor_profile(
    State(pool): State<PgPool>,
    Json(payload): Json<UpdateDoctorProfileReq>,
) -> Result<Json<DoctorProfile>, (StatusCode, String)> {
    let mut tx = pool.begin().await.map_err(internal_error)?;

    let doctor_row_raw = sqlx::query!(
        r#"
        SELECT
            u.user_id,
            u.email,
            u.first_name,
            u.last_name,
            u.phone,
            u.citizen_id,
            dp.mln as "mln?",
            dp.department as "department?",
            dp.position as "position?"
        FROM users u
        LEFT JOIN doctor_profile dp ON dp.user_id = u.user_id
        WHERE u.user_id = $1
        "#,
        payload.user_id
    )
    .fetch_optional(&mut *tx)
    .await
    .map_err(internal_error)?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "Doctor not found".to_string()))?;

    let doctor_row = DoctorRecord {
        user_id: doctor_row_raw.user_id,
        email: doctor_row_raw.email,
        first_name: doctor_row_raw.first_name,
        last_name: doctor_row_raw.last_name,
        phone: doctor_row_raw.phone,
        citizen_id: doctor_row_raw.citizen_id,
        mln: doctor_row_raw.mln,
        department: doctor_row_raw.department,
        position: doctor_row_raw.position,
    };

    let UpdateDoctorProfileReq {
        user_id,
        first_name,
        last_name,
        email,
        phone,
        department,
        position,
        mln,
        schedule,
    } = payload;

    let first_name = first_name.trim().to_string();
    let last_name = last_name.trim().to_string();
    let email = email.trim().to_string();
    let phone = phone.trim().to_string();
    let department = normalize_optional_string(department);
    let position = normalize_optional_string(position);
    let mln_candidate = normalize_optional_string(mln);
    let existing_mln = doctor_row.mln.clone();

    if first_name.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            "First name is required".to_string(),
        ));
    }
    if email.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Email is required".to_string()));
    }
    if phone.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            "Phone number is required".to_string(),
        ));
    }

    let final_mln = mln_candidate.or(existing_mln).ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            "Medical license is required".to_string(),
        )
    })?;

    sqlx::query!(
        r#"
        UPDATE users
        SET first_name = $1,
            last_name = $2,
            email = $3,
            phone = $4
        WHERE user_id = $5
        "#,
        first_name,
        last_name,
        email,
        phone,
        user_id
    )
    .execute(&mut *tx)
    .await
    .map_err(internal_error)?;

    sqlx::query!(
        r#"
        INSERT INTO doctor_profile (user_id, mln, department, position)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id) DO UPDATE SET
            mln = EXCLUDED.mln,
            department = EXCLUDED.department,
            position = EXCLUDED.position
        "#,
        user_id,
        final_mln,
        department,
        position
    )
    .execute(&mut *tx)
    .await
    .map_err(internal_error)?;

    sqlx::query!(r#"DELETE FROM time_slots WHERE doctor_id = $1"#, user_id)
        .execute(&mut *tx)
        .await
        .map_err(internal_error)?;

    let mut normalized_slots = Vec::new();
    for slot in schedule.into_iter() {
        if !(0..=6).contains(&slot.day_of_week) {
            continue;
        }

        let start = parse_schedule_time(&slot.start_time)?;
        let end = parse_schedule_time(&slot.end_time)?;
        if start >= end {
            return Err((
                StatusCode::BAD_REQUEST,
                format!(
                    "Invalid time range: {} - {}",
                    slot.start_time.trim(),
                    slot.end_time.trim()
                ),
            ));
        }

        let place_name = slot.place_name.trim().to_string();
        if place_name.is_empty() {
            continue;
        }

        normalized_slots.push((slot.day_of_week, start, end, place_name));
    }

    for (day_of_week, start, end, place_name) in normalized_slots {
        sqlx::query!(
            r#"
            INSERT INTO time_slots (doctor_id, day_of_weeks, start_time, end_time, place_name)
            VALUES ($1, $2, $3, $4, $5)
            "#,
            user_id,
            day_of_week,
            start,
            end,
            place_name
        )
        .execute(&mut *tx)
        .await
        .map_err(internal_error)?;
    }

    tx.commit().await.map_err(internal_error)?;

    let updated_profile = fetch_doctor_profile_by_user_id(&pool, user_id).await?;
    Ok(Json(updated_profile))
}

async fn fetch_doctor_profile_by_email(
    pool: &PgPool,
    email: &str,
) -> Result<DoctorProfile, (StatusCode, String)> {
    let email_trimmed = email.trim();
    let record = sqlx::query!(
        r#"
        SELECT
            u.user_id,
            u.email,
            u.first_name,
            u.last_name,
            u.phone,
            u.citizen_id,
            dp.mln as "mln?",
            dp.department as "department?",
            dp.position as "position?"
        FROM users u
        LEFT JOIN doctor_profile dp ON dp.user_id = u.user_id
        WHERE u.email = $1
        "#,
        email_trimmed
    )
    .fetch_optional(pool)
    .await
    .map_err(internal_error)?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "Doctor not found".to_string()))?;

    build_doctor_profile(
        pool,
        DoctorRecord {
            user_id: record.user_id,
            email: record.email,
            first_name: record.first_name,
            last_name: record.last_name,
            phone: record.phone,
            citizen_id: record.citizen_id,
            mln: record.mln,
            department: record.department,
            position: record.position,
        },
    )
    .await
}

async fn fetch_doctor_profile_by_user_id(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<DoctorProfile, (StatusCode, String)> {
    let record = sqlx::query!(
        r#"
        SELECT
            u.user_id,
            u.email,
            u.first_name,
            u.last_name,
            u.phone,
            u.citizen_id,
            dp.mln as "mln?",
            dp.department as "department?",
            dp.position as "position?"
        FROM users u
        LEFT JOIN doctor_profile dp ON dp.user_id = u.user_id
        WHERE u.user_id = $1
        "#,
        user_id
    )
    .fetch_optional(pool)
    .await
    .map_err(internal_error)?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "Doctor not found".to_string()))?;

    build_doctor_profile(
        pool,
        DoctorRecord {
            user_id: record.user_id,
            email: record.email,
            first_name: record.first_name,
            last_name: record.last_name,
            phone: record.phone,
            citizen_id: record.citizen_id,
            mln: record.mln,
            department: record.department,
            position: record.position,
        },
    )
    .await
}

async fn build_doctor_profile(
    pool: &PgPool,
    record: DoctorRecord,
) -> Result<DoctorProfile, (StatusCode, String)> {
    let schedule_rows = sqlx::query!(
        r#"
        SELECT
            day_of_weeks,
            start_time,
            end_time,
            place_name
        FROM time_slots
        WHERE doctor_id = $1
        ORDER BY day_of_weeks, start_time
        "#,
        record.user_id
    )
    .fetch_all(pool)
    .await
    .map_err(internal_error)?;

    let schedule = schedule_rows
        .into_iter()
        .map(|row| DoctorScheduleSlot {
            day_of_week: row.day_of_weeks,
            day_name: map_day_name(row.day_of_weeks),
            start_time: format_time(row.start_time),
            end_time: format_time(row.end_time),
            place_name: row.place_name,
        })
        .collect();

    let DoctorRecord {
        user_id,
        email,
        first_name,
        last_name,
        phone,
        citizen_id,
        mln,
        department,
        position,
    } = record;

    Ok(DoctorProfile {
        user_id,
        email: email.unwrap_or_default(),
        first_name,
        last_name,
        phone,
        citizen_id,
        mln,
        department,
        position,
        schedule,
    })
}

fn parse_schedule_time(raw: &str) -> Result<Time, (StatusCode, String)> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            "Time value is required".to_string(),
        ));
    }
    let parts: Vec<_> = trimmed.split(':').collect();
    if !(2..=3).contains(&parts.len()) {
        return Err((
            StatusCode::BAD_REQUEST,
            format!("Invalid time format: {trimmed}"),
        ));
    }
    let hour = parts[0].parse::<u8>().map_err(|_| {
        (
            StatusCode::BAD_REQUEST,
            format!("Invalid hour in time: {trimmed}"),
        )
    })?;
    let minute = parts[1].parse::<u8>().map_err(|_| {
        (
            StatusCode::BAD_REQUEST,
            format!("Invalid minute in time: {trimmed}"),
        )
    })?;
    let second = if parts.len() == 3 {
        parts[2].parse::<u8>().map_err(|_| {
            (
                StatusCode::BAD_REQUEST,
                format!("Invalid second in time: {trimmed}"),
            )
        })?
    } else {
        0
    };
    Time::from_hms(hour, minute, second).map_err(|_| {
        (
            StatusCode::BAD_REQUEST,
            format!("Time is out of range: {trimmed}"),
        )
    })
}

fn normalize_optional_string(value: Option<String>) -> Option<String> {
    value.and_then(|v| {
        let trimmed = v.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    })
}

fn format_time(time: Time) -> String {
    format!("{:02}:{:02}", time.hour(), time.minute())
}

fn map_day_name(day: i32) -> String {
    match day {
        0 => "วันอาทิตย์".to_string(),
        1 => "วันจันทร์".to_string(),
        2 => "วันอังคาร".to_string(),
        3 => "วันพุธ".to_string(),
        4 => "วันพฤหัสบดี".to_string(),
        5 => "วันศุกร์".to_string(),
        6 => "วันเสาร์".to_string(),
        other => {
            let mut fallback = String::from("Day ");
            let _ = write!(&mut fallback, "{other}");
            fallback
        }
    }
}

fn internal_error<E: std::error::Error>(err: E) -> (StatusCode, String) {
    (StatusCode::INTERNAL_SERVER_ERROR, err.to_string())
}
