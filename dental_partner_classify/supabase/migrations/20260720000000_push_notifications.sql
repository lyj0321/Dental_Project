-- 푸시 알림 기능: hospitals 테이블에 FCM 토큰 및 알림 설정 컬럼 추가
alter table hospitals
  add column if not exists fcm_token text,
  add column if not exists notify_new_booking boolean not null default true,
  add column if not exists notify_review boolean not null default true,
  add column if not exists notify_patient_arrival boolean not null default true,
  add column if not exists arrival_reminder_minutes int not null default 30;
