use axum::{Router, routing::post};
use common::config::AppConfig;
use sqlx::PgPool;

mod handlers;
mod models;

pub fn router(db: PgPool, cfg: AppConfig) -> Router {
    Router::new()
        .nest(
            "/auth",
            Router::new()
                .route("/register", post(handlers::register))
                .route("/login", post(handlers::login)),
        )
        .with_state((db, cfg))
}
