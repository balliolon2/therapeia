use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Deserialize)]
pub struct ProfileQuery {
    pub email: String,
}

#[derive(Serialize)]
pub struct PatientProfile {
    pub user_id: Uuid,
    pub email: String,
    pub first_name: String,
    pub last_name: String,
    pub phone: String,
    pub citizen_id: String,
    pub hn: Option<i32>,
    pub age: Option<i32>,
    pub height_cm: Option<f64>,
    pub weight_kg: Option<f64>,
    pub medical_conditions: Option<String>,
    pub drug_allergies: Option<String>,
}

#[derive(Serialize)]
pub struct DoctorProfile {
    pub user_id: Uuid,
    pub email: String,
    pub first_name: String,
    pub last_name: String,
    pub phone: String,
    pub citizen_id: String,
    pub mln: Option<String>,
    pub department: Option<String>,
    pub position: Option<String>,
    pub schedule: Vec<DoctorScheduleSlot>,
}

#[derive(Serialize)]
pub struct DoctorScheduleSlot {
    pub day_of_week: i32,
    pub day_name: String,
    pub start_time: String,
    pub end_time: String,
    pub place_name: String,
}

#[derive(Deserialize)]
pub struct UpdateDoctorProfileReq {
    pub user_id: Uuid,
    pub first_name: String,
    pub last_name: String,
    pub email: String,
    pub phone: String,
    pub department: Option<String>,
    pub position: Option<String>,
    pub mln: Option<String>,
    #[serde(default)]
    pub schedule: Vec<UpdateDoctorScheduleSlot>,
}

#[derive(Deserialize)]
pub struct UpdateDoctorScheduleSlot {
    pub day_of_week: i32,
    pub start_time: String,
    pub end_time: String,
    pub place_name: String,
}
