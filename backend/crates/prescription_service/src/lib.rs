use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, post, put},
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Serialize)]
pub struct PrescriptionDto {
    pub prescription_id: i32,
    pub patient_id: Uuid,
    pub medicine_id: i32,
    pub medicine_name: String,
    pub medicine_details: Option<String>,
    pub image_url: Option<String>,
    pub dosage: String,
    pub amount: i32,
    pub on_going: bool,
    pub doctor_comment: Option<String>,
}

#[derive(Serialize)]
pub struct MedicineDto {
    pub medicine_id: i32,
    pub medicine_name: String,
    pub details: Option<String>,
    pub image_url: Option<String>,
    pub unit_price: Option<f64>,
}

#[derive(Deserialize)]
pub struct PatientPrescriptionsQuery {
    pub patient_id: Uuid,
}

#[derive(Deserialize)]
pub struct UpsertPrescriptionReq {
    pub patient_id: Uuid,
    pub medicine_id: i32,
    pub dosage: String,
    pub amount: i32,
    pub on_going: bool,
    pub doctor_comment: Option<String>,
}

#[derive(Deserialize)]
pub struct MedicineQuery {
    pub q: Option<String>,
    pub limit: Option<i64>,
}

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/prescriptions/patient", get(list_patient_prescriptions))
        .route("/prescriptions", post(create_prescription))
        .route(
            "/prescriptions/{id}",
            put(update_prescription).delete(delete_prescription),
        )
        .route("/medicines", get(list_medicines))
        .with_state(pool)
}

async fn list_patient_prescriptions(
    State(pool): State<PgPool>,
    Query(query): Query<PatientPrescriptionsQuery>,
) -> Result<Json<Vec<PrescriptionDto>>, (StatusCode, String)> {
    let rows = sqlx::query!(
        r#"
        SELECT
            p.prescription_id,
            p.patient_id,
            p.medicine_id,
            p.dosage,
            p.amount,
            p.on_going,
            p.doctor_comment,
            m.medicine_name,
            m.details as "medicine_details?",
            m.image_url,
            m.unit_price::float as "unit_price?"
        FROM prescriptions p
        JOIN medicines m ON m.medicine_id = p.medicine_id
        WHERE p.patient_id = $1
        ORDER BY p.on_going DESC, p.prescription_id DESC
        "#,
        query.patient_id
    )
    .fetch_all(&pool)
    .await
    .map_err(internal_error)?;

    let results = rows
        .into_iter()
        .map(|row| PrescriptionDto {
            prescription_id: row.prescription_id,
            patient_id: row.patient_id,
            medicine_id: row.medicine_id,
            medicine_name: row.medicine_name,
            medicine_details: row.medicine_details,
            image_url: row.image_url,
            dosage: row.dosage,
            amount: row.amount,
            on_going: row.on_going,
            doctor_comment: row.doctor_comment,
        })
        .collect();

    Ok(Json(results))
}

async fn create_prescription(
    State(pool): State<PgPool>,
    Json(payload): Json<UpsertPrescriptionReq>,
) -> Result<Json<PrescriptionDto>, (StatusCode, String)> {
    let row = sqlx::query!(
        r#"
        WITH inserted AS (
            INSERT INTO prescriptions (patient_id, medicine_id, dosage, amount, on_going, doctor_comment)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING prescription_id, patient_id, medicine_id, dosage, amount, on_going, doctor_comment
        )
        SELECT
            i.prescription_id,
            i.patient_id,
            i.medicine_id,
            i.dosage,
            i.amount,
            i.on_going,
            i.doctor_comment,
            m.medicine_name,
            m.details as "medicine_details?",
            m.image_url
        FROM inserted i
        JOIN medicines m ON m.medicine_id = i.medicine_id
        "#,
        payload.patient_id,
        payload.medicine_id,
        payload.dosage,
        payload.amount,
        payload.on_going,
        payload.doctor_comment
    )
    .fetch_one(&pool)
    .await
    .map_err(internal_error)?;

    Ok(Json(PrescriptionDto {
        prescription_id: row.prescription_id,
        patient_id: row.patient_id,
        medicine_id: row.medicine_id,
        medicine_name: row.medicine_name,
        medicine_details: row.medicine_details,
        image_url: row.image_url,
        dosage: row.dosage,
        amount: row.amount,
        on_going: row.on_going,
        doctor_comment: row.doctor_comment,
    }))
}

async fn update_prescription(
    State(pool): State<PgPool>,
    Path(id): Path<i32>,
    Json(payload): Json<UpsertPrescriptionReq>,
) -> Result<Json<PrescriptionDto>, (StatusCode, String)> {
    let row = sqlx::query!(
        r#"
        WITH updated AS (
            UPDATE prescriptions
            SET
                patient_id = $2,
                medicine_id = $3,
                dosage = $4,
                amount = $5,
                on_going = $6,
                doctor_comment = $7
            WHERE prescription_id = $1
            RETURNING prescription_id, patient_id, medicine_id, dosage, amount, on_going, doctor_comment
        )
        SELECT
            u.prescription_id,
            u.patient_id,
            u.medicine_id,
            u.dosage,
            u.amount,
            u.on_going,
            u.doctor_comment,
            m.medicine_name,
            m.details as "medicine_details?",
            m.image_url
        FROM updated u
        JOIN medicines m ON m.medicine_id = u.medicine_id
        "#,
        id,
        payload.patient_id,
        payload.medicine_id,
        payload.dosage,
        payload.amount,
        payload.on_going,
        payload.doctor_comment
    )
    .fetch_optional(&pool)
    .await
    .map_err(internal_error)?;

    let Some(row) = row else {
        return Err((StatusCode::NOT_FOUND, "Prescription not found".into()));
    };

    Ok(Json(PrescriptionDto {
        prescription_id: row.prescription_id,
        patient_id: row.patient_id,
        medicine_id: row.medicine_id,
        medicine_name: row.medicine_name,
        medicine_details: row.medicine_details,
        image_url: row.image_url,
        dosage: row.dosage,
        amount: row.amount,
        on_going: row.on_going,
        doctor_comment: row.doctor_comment,
    }))
}

async fn delete_prescription(
    State(pool): State<PgPool>,
    Path(id): Path<i32>,
) -> Result<StatusCode, (StatusCode, String)> {
    let result = sqlx::query!(
        r#"DELETE FROM prescriptions WHERE prescription_id = $1"#,
        id
    )
    .execute(&pool)
    .await
    .map_err(internal_error)?;

    if result.rows_affected() == 0 {
        return Err((StatusCode::NOT_FOUND, "Prescription not found".into()));
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn list_medicines(
    State(pool): State<PgPool>,
    Query(query): Query<MedicineQuery>,
) -> Result<Json<Vec<MedicineDto>>, (StatusCode, String)> {
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let keyword = query.q.map(|k| format!("%{}%", k));

    let rows = sqlx::query!(
        r#"
        SELECT
            medicine_id,
            medicine_name,
            details,
            image_url,
            unit_price::float as "unit_price?"
        FROM medicines
        WHERE $1::text IS NULL OR medicine_name ILIKE $1
        ORDER BY medicine_name
        LIMIT $2
        "#,
        keyword,
        limit
    )
    .fetch_all(&pool)
    .await
    .map_err(internal_error)?;

    let medicines = rows
        .into_iter()
        .map(|row| MedicineDto {
            medicine_id: row.medicine_id,
            medicine_name: row.medicine_name,
            details: row.details,
            image_url: row.image_url,
            unit_price: row.unit_price,
        })
        .collect();

    Ok(Json(medicines))
}

fn internal_error<E: std::error::Error>(err: E) -> (StatusCode, String) {
    (StatusCode::INTERNAL_SERVER_ERROR, err.to_string())
}
