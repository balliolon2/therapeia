use axum::{Router, routing::get};
use sqlx::PgPool;

mod handlers;
mod models;

pub fn router(pool: PgPool) -> Router {
    Router::new()
        .route("/profiles/patient", get(handlers::get_patient_profile))
        .route(
            "/profiles/doctor",
            get(handlers::get_doctor_profile).put(handlers::update_doctor_profile),
        )
        .with_state(pool)
}
