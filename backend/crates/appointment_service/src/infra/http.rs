use super::repo_sqlx::SqlxAppointmentRepo;
use crate::{
    app::{AppointmentRepo, AppointmentService},
    domain::{Appointment, AppointmentStatus, NewAppointment},
};
use axum::{
    Json, Router,
    extract::{Path, State},
    routing::{get, post},
};
use common::error::{AppError, AppResult};
use db::PgTx;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::{OpenApi, ToSchema};
use uuid::Uuid;

#[derive(Clone)]
pub struct Ctx {
    pool: PgPool,
    svc: AppointmentService<SqlxAppointmentRepo>,
}

impl Ctx {
    pub fn new(pool: PgPool) -> Self {
        let svc = AppointmentService::new(SqlxAppointmentRepo::new(pool.clone()));
        Self { pool, svc }
    }
}

#[derive(Deserialize, ToSchema)]
pub struct BookReq {
    pub patient_id: Uuid,
    pub timeslot_id: i32,
    pub date: time::Date,
}

#[derive(Deserialize)]
pub struct DoctorAppointmentsQuery {
    pub email: String,
    pub start: Option<time::Date>,
    pub end: Option<time::Date>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct DoctorAppointmentSummary {
    pub appointment_id: i32,
    pub date: time::Date,
    #[schema(value_type = String, format = "time", example = "09:00")]
    pub start_time: String,
    #[schema(value_type = String, format = "time", example = "10:00")]
    pub end_time: String,
    pub place_name: String,
    pub patient_id: Uuid,
    pub patient_name: String,
    pub patient_age: Option<i32>,
    pub patient_height_cm: Option<f64>,
    pub patient_weight_kg: Option<f64>,
    pub medical_conditions: Option<String>,
    pub drug_allergies: Option<String>,
    pub latest_diagnosis: Option<String>,
    pub status: AppointmentStatus,
}

fn format_time(t: time::Time) -> String {
    format!("{:02}:{:02}", t.hour(), t.minute())
}

#[utoipa::path(
    post,
    path = "/",
    request_body = BookReq,
    responses(
        (status = 200, description = "Book appointment successfully", body = Appointment),
        (status = 404, description = "Patient or timeslot not found"),
    ),
    tag = "appointments"
)]
async fn book(State(ctx): State<Ctx>, Json(req): Json<BookReq>) -> AppResult<Json<Appointment>> {
    let mut tx: PgTx<'_> = ctx.pool.begin().await?;
    let appt = ctx
        .svc
        .book(
            &mut tx,
            NewAppointment {
                patient_id: req.patient_id,
                timeslot_id: req.timeslot_id,
                date: req.date,
            },
        )
        .await?;
    tx.commit().await?;
    Ok(Json(appt))
}

#[utoipa::path(
    get,
    path = "/{id}",
    params(
        ("id" = i32, Path, description = "Appointment ID")
    ),
    responses(
        (status = 200, description = "Appointment found", body = Appointment),
        (status = 404, description = "Appointment not found"),
    ),
    tag = "appointments"
)]
async fn get_by_id(State(ctx): State<Ctx>, Path(id): Path<i32>) -> AppResult<Json<Appointment>> {
    let Some(a) = ctx.svc.repo.by_id(id).await? else {
        return Err(AppError::NotFound);
    };
    Ok(Json(a))
}

#[utoipa::path(
    get,
    path = "/doctor",
    params(
        ("email" = String, Query, description = "Doctor email"),
        ("start" = Option<time::Date>, Query, description = "Start date filter"),
        ("end" = Option<time::Date>, Query, description = "End date filter")
    ),
    responses(
        (status = 200, description = "Doctor appointments", body = Vec<DoctorAppointmentSummary>),
        (status = 404, description = "Doctor not found"),
    ),
    tag = "appointments"
)]
async fn list_doctor_appointments(
    State(ctx): State<Ctx>,
    axum::extract::Query(query): axum::extract::Query<DoctorAppointmentsQuery>,
) -> AppResult<Json<Vec<DoctorAppointmentSummary>>> {
    let rows = sqlx::query!(
        r#"
        SELECT
            a.appointment_id,
            a.date,
            a.status as "status: AppointmentStatus",
            ts.start_time,
            ts.end_time,
            ts.place_name,
            pt.user_id AS patient_id,
            pt.first_name,
            pt.last_name,
            phi.age,
            phi.height_cm::float AS "height_cm?",
            phi.weight_kg::float AS "weight_kg?",
            phi.medical_conditions,
            phi.drug_allergies,
            diag.symptom AS "latest_diagnosis?"
        FROM appointments a
        JOIN time_slots ts ON ts.timeslot_id = a.timeslot_id
        JOIN users doc ON doc.user_id = ts.doctor_id
        JOIN users pt ON pt.user_id = a.patient_id
        LEFT JOIN patient_health_info phi ON phi.patient_id = pt.user_id
        LEFT JOIN LATERAL (
            SELECT symptom
            FROM diagnoses dd
            WHERE dd.appointment_id = a.appointment_id
            ORDER BY dd.recorded_at DESC
            LIMIT 1
        ) diag ON TRUE
        WHERE doc.email = $1
          AND ($2::date IS NULL OR a.date >= $2)
          AND ($3::date IS NULL OR a.date <= $3)
        ORDER BY a.date, ts.start_time
        "#,
        query.email,
        query.start,
        query.end,
    )
    .fetch_all(&ctx.pool)
    .await?;

    if rows.is_empty() {
        // Validate doctor existence to distinguish between "no appointments" and "doctor not found"
        let doc_exists = sqlx::query_scalar!(
            r#"
            SELECT EXISTS (
                SELECT 1
                FROM users u
                JOIN user_roles ur ON ur.user_id = u.user_id
                WHERE u.email = $1 AND ur.role = 'DOCTOR'
            ) AS "exists!"
            "#,
            query.email
        )
        .fetch_one(&ctx.pool)
        .await?;

        if !doc_exists {
            return Err(AppError::NotFound);
        }
    }

    let appts = rows
        .into_iter()
        .map(|row| {
            let patient_name = [row.first_name, row.last_name]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<Vec<_>>()
                .join(" ");

            DoctorAppointmentSummary {
                appointment_id: row.appointment_id,
                date: row.date,
                start_time: format_time(row.start_time),
                end_time: format_time(row.end_time),
                place_name: row.place_name,
                patient_id: row.patient_id,
                patient_name,
                patient_age: row.age,
                patient_height_cm: row.height_cm,
                patient_weight_kg: row.weight_kg,
                medical_conditions: row.medical_conditions,
                drug_allergies: row.drug_allergies,
                latest_diagnosis: row.latest_diagnosis,
                status: row.status,
            }
        })
        .collect();

    Ok(Json(appts))
}

pub fn router(pool: PgPool) -> Router {
    let ctx = Ctx::new(pool);
    Router::new()
        .route("/appointments", post(book))
        .route("/appointments/doctor", get(list_doctor_appointments))
        .route("/appointments/{id}", get(get_by_id))
        .with_state(ctx)
}

#[derive(OpenApi, Default)]
#[openapi(
    paths(book, get_by_id, list_doctor_appointments),
    components(schemas(BookReq, Appointment, DoctorAppointmentSummary, AppointmentStatus)),
    tags((name = "appointments", description = "Appointment APIs"))
)]
pub struct ApiDoc;
