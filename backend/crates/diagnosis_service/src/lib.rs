use axum::{
    Json, Router,
    extract::{Query, State},
    http::StatusCode,
    routing::get,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use time::OffsetDateTime;
use uuid::Uuid;

#[derive(Deserialize)]
pub struct PatientDiagnosesQuery {
    pub patient_id: Uuid,
    pub limit: Option<i64>,
}

#[derive(Serialize)]
pub struct DiagnosisEntry {
    pub diagnosis_id: i32,
    pub appointment_id: i32,
    pub doctor_id: Uuid,
    pub symptom: String,
    pub recorded_at: OffsetDateTime,
}

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/diagnoses/patient", get(list_patient_diagnoses))
        .with_state(pool)
}

async fn list_patient_diagnoses(
    State(pool): State<PgPool>,
    Query(query): Query<PatientDiagnosesQuery>,
) -> Result<Json<Vec<DiagnosisEntry>>, (StatusCode, String)> {
    let limit = query.limit.unwrap_or(50).clamp(1, 200);

    let rows = sqlx::query!(
        r#"
        SELECT
            diagnosis_id,
            appointment_id,
            doctor_id,
            symptom,
            recorded_at
        FROM diagnoses
        WHERE patient_id = $1
        ORDER BY recorded_at DESC
        LIMIT $2
        "#,
        query.patient_id,
        limit
    )
    .fetch_all(&pool)
    .await
    .map_err(internal_error)?;

    let entries = rows
        .into_iter()
        .map(|row| DiagnosisEntry {
            diagnosis_id: row.diagnosis_id,
            appointment_id: row.appointment_id,
            doctor_id: row.doctor_id,
            symptom: row.symptom,
            recorded_at: row.recorded_at,
        })
        .collect();

    Ok(Json(entries))
}

fn internal_error<E: std::error::Error>(err: E) -> (StatusCode, String) {
    (StatusCode::INTERNAL_SERVER_ERROR, err.to_string())
}
