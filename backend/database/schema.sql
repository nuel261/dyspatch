-- Dyspatch platform schema (MySQL 5.7+/MariaDB 10.3+)
-- All money columns are integers in KOBO (₦1 = 100 kobo). Never store naira floats.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS admins (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('super','ops','support') NOT NULL DEFAULT 'ops',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS zones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  code VARCHAR(6) NOT NULL UNIQUE,          -- used as Track ID prefix e.g. BEN-48213
  city VARCHAR(100) NOT NULL,
  center_lat DECIMAL(10,7) NOT NULL,
  center_lng DECIMAL(10,7) NOT NULL,
  radius_km DECIMAL(6,2) NOT NULL DEFAULT 15,
  polygon JSON NULL,                         -- optional [[lat,lng],...] geofence; overrides radius when set
  is_live TINYINT(1) NOT NULL DEFAULT 0,     -- launch gating
  commission_pct DECIMAL(5,2) NULL,          -- NULL = use global setting
  pricing_model ENUM('distance_only','min_fare') NULL,
  base_fare_kobo INT UNSIGNED NULL,
  per_km_kobo INT UNSIGNED NULL,
  min_fare_kobo INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS settings (
  `key` VARCHAR(80) PRIMARY KEY,
  `value` TEXT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NULL,
  last_name VARCHAR(80) NULL,
  email VARCHAR(190) NULL,
  phone VARCHAR(20) NULL UNIQUE,
  password_hash VARCHAR(255) NULL,
  avatar VARCHAR(255) NULL,
  address VARCHAR(255) NULL,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  firebase_uid VARCHAR(128) NULL UNIQUE,
  default_delivery_type ENUM('standard','express') NOT NULL DEFAULT 'standard',
  auto_assign TINYINT(1) NOT NULL DEFAULT 1,
  two_factor TINYINT(1) NOT NULL DEFAULT 0,
  business_verified TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('active','suspended') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Riders are independent platform users (never employees).
CREATE TABLE IF NOT EXISTS riders (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL DEFAULT '',
  last_name VARCHAR(80) NOT NULL DEFAULT '',
  email VARCHAR(190) NULL,
  phone VARCHAR(20) NOT NULL UNIQUE,
  photo VARCHAR(255) NULL,
  vehicle_type ENUM('bike','bicycle','car','truck') NOT NULL DEFAULT 'bike',
  plate VARCHAR(20) NULL,
  zone_id INT UNSIGNED NULL,
  kyc_status ENUM('none','submitted','verified','rejected') NOT NULL DEFAULT 'none',
  kyc_provider VARCHAR(30) NULL,
  kyc_reference VARCHAR(100) NULL,
  id_type VARCHAR(30) NULL,
  id_number VARCHAR(40) NULL,
  id_document VARCHAR(255) NULL,
  status ENUM('pending','active','suspended') NOT NULL DEFAULT 'pending',
  suspension_reason VARCHAR(255) NULL,       -- platform-policy (ToS) reason, not HR
  is_online TINYINT(1) NOT NULL DEFAULT 0,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  heading DECIMAL(5,1) NULL,
  location_updated_at DATETIME NULL,
  rating DECIMAL(3,2) NOT NULL DEFAULT 5.00,
  rating_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_online (is_online, status, zone_id),
  CONSTRAINT fk_rider_zone FOREIGN KEY (zone_id) REFERENCES zones(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_tokens (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_type ENUM('user','rider') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  device VARCHAR(120) NULL,
  expires_at DATETIME NOT NULL,
  last_used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_owner (owner_type, owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS device_tokens (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_type ENUM('user','rider') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  fcm_token VARCHAR(255) NOT NULL UNIQUE,
  platform VARCHAR(20) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_owner (owner_type, owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4-digit OTPs, 30 min expiry, locked after 3 failed attempts (values from settings).
CREATE TABLE IF NOT EXISTS otps (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  purpose VARCHAR(20) NOT NULL DEFAULT 'login',
  code_hash VARCHAR(255) NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  is_locked TINYINT(1) NOT NULL DEFAULT 0,
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_phone (phone, purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_no VARCHAR(20) NOT NULL UNIQUE,          -- DY-00421
  track_id VARCHAR(20) NOT NULL UNIQUE,          -- BEN-48213
  user_id INT UNSIGNED NULL,
  created_by_admin INT UNSIGNED NULL,
  zone_id INT UNSIGNED NULL,
  channel ENUM('app','web','admin','api') NOT NULL DEFAULT 'app',
  sender_name VARCHAR(120) NULL,
  sender_phone VARCHAR(20) NULL,
  pickup_address VARCHAR(255) NOT NULL,
  pickup_lat DECIMAL(10,7) NULL,
  pickup_lng DECIMAL(10,7) NULL,
  dropoff_address VARCHAR(255) NOT NULL,
  dropoff_lat DECIMAL(10,7) NULL,
  dropoff_lng DECIMAL(10,7) NULL,
  recipient_name VARCHAR(120) NOT NULL,
  recipient_phone VARCHAR(20) NOT NULL,
  package_type ENUM('small','medium','large') NOT NULL DEFAULT 'medium',
  package_description VARCHAR(255) NULL,
  delivery_type ENUM('standard','express') NOT NULL DEFAULT 'standard',
  distance_km DECIMAL(8,2) NOT NULL DEFAULT 0,
  fee_kobo INT UNSIGNED NOT NULL DEFAULT 0,
  commission_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
  commission_kobo INT UNSIGNED NOT NULL DEFAULT 0,
  rider_earning_kobo INT UNSIGNED NOT NULL DEFAULT 0,
  payment_method ENUM('wallet','cash','card') NOT NULL DEFAULT 'wallet',
  payment_status ENUM('unpaid','paid','refunded') NOT NULL DEFAULT 'unpaid',
  status ENUM('pending','matched','picked_up','en_route','arrived','delivered','cancelled','failed') NOT NULL DEFAULT 'pending',
  rider_id INT UNSIGNED NULL,
  eta_minutes INT NULL,
  pickup_code CHAR(4) NULL,                      -- sender gives to rider at pickup
  delivery_code CHAR(4) NULL,                    -- recipient gives to rider at handover
  delivery_code_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  delivery_code_expires_at DATETIME NULL,
  share_token VARCHAR(40) NULL UNIQUE,
  share_expires_at DATETIME NULL,
  insurance_ref VARCHAR(100) NULL,               -- extension point for in-app insurance
  cancel_reason VARCHAR(255) NULL,
  proof_photo VARCHAR(255) NULL,
  rider_rating TINYINT NULL,
  matched_at DATETIME NULL,
  picked_up_at DATETIME NULL,
  arrived_at DATETIME NULL,
  delivered_at DATETIME NULL,
  cancelled_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_status (status),
  KEY idx_user (user_id),
  KEY idx_rider (rider_id),
  KEY idx_created (created_at),
  CONSTRAINT fk_order_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_order_rider FOREIGN KEY (rider_id) REFERENCES riders(id) ON DELETE SET NULL,
  CONSTRAINT fk_order_zone FOREIGN KEY (zone_id) REFERENCES zones(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Each parcel/item inside an order is individually trackable (item_code e.g. BEN-48213-01)
CREATE TABLE IF NOT EXISTS order_items (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  item_code VARCHAR(30) NOT NULL UNIQUE,
  description VARCHAR(255) NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  weight_kg DECIMAL(8,2) NULL,
  value_kobo INT UNSIGNED NULL,
  status ENUM('pending','picked_up','in_transit','delivered','returned','lost','damaged') NOT NULL DEFAULT 'pending',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_item_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tracking_events (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NULL,
  status VARCHAR(30) NOT NULL,
  title VARCHAR(120) NOT NULL,
  note VARCHAR(255) NULL,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  actor_type ENUM('system','admin','rider','user') NOT NULL DEFAULT 'system',
  actor_id INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order (order_id, created_at),
  CONSTRAINT fk_event_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_event_item FOREIGN KEY (item_id) REFERENCES order_items(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS rider_locations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rider_id INT UNSIGNED NOT NULL,
  order_id INT UNSIGNED NULL,
  lat DECIMAL(10,7) NOT NULL,
  lng DECIMAL(10,7) NOT NULL,
  heading DECIMAL(5,1) NULL,
  speed DECIMAL(6,2) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order (order_id, created_at),
  KEY idx_rider (rider_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS order_offers (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  rider_id INT UNSIGNED NOT NULL,
  distance_km DECIMAL(8,2) NULL,
  status ENUM('offered','accepted','declined','expired','withdrawn') NOT NULL DEFAULT 'offered',
  offered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  responded_at DATETIME NULL,
  KEY idx_order (order_id),
  KEY idx_rider (rider_id, status),
  CONSTRAINT fk_offer_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_offer_rider FOREIGN KEY (rider_id) REFERENCES riders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_type ENUM('user','rider','platform') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  balance_kobo BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_owner (owner_type, owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  wallet_id INT UNSIGNED NOT NULL,
  type ENUM('credit','debit') NOT NULL,
  category ENUM('topup','delivery_payment','delivery_earning','commission','withdrawal','withdrawal_fee','refund','adjustment') NOT NULL,
  amount_kobo BIGINT NOT NULL,
  balance_after_kobo BIGINT NOT NULL,
  reference VARCHAR(60) NOT NULL UNIQUE,
  description VARCHAR(255) NULL,
  order_id INT UNSIGNED NULL,
  meta JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_wallet (wallet_id, created_at),
  CONSTRAINT fk_tx_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS topup_requests (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  reference VARCHAR(40) NOT NULL UNIQUE,
  amount_kobo BIGINT NULL,                      -- bank transfer: admin enters confirmed amount
  method ENUM('bank_transfer','paystack','flutterwave') NOT NULL DEFAULT 'bank_transfer',
  status ENUM('awaiting','pending','confirmed','rejected') NOT NULL DEFAULT 'awaiting',
  admin_id INT UNSIGNED NULL,
  note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmed_at DATETIME NULL,
  KEY idx_status (status),
  CONSTRAINT fk_topup_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bank_accounts (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_type ENUM('user','rider') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  bank_name VARCHAR(100) NOT NULL,
  bank_code VARCHAR(10) NULL,
  account_name VARCHAR(150) NOT NULL,
  account_number VARCHAR(20) NOT NULL,
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  recipient_code VARCHAR(60) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_owner (owner_type, owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS withdrawals (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reference VARCHAR(40) NOT NULL UNIQUE,
  owner_type ENUM('user','rider') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  bank_account_id INT UNSIGNED NULL,
  amount_kobo BIGINT NOT NULL,
  fee_kobo BIGINT NOT NULL DEFAULT 0,
  net_kobo BIGINT NOT NULL,
  status ENUM('pending','processing','paid','failed','rejected') NOT NULL DEFAULT 'pending',
  scheduled_for DATE NOT NULL,                   -- before 5PM WAT → same day, else next business day
  provider VARCHAR(20) NULL,                     -- paystack | flutterwave | manual
  provider_ref VARCHAR(100) NULL,
  admin_id INT UNSIGNED NULL,
  note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processed_at DATETIME NULL,
  KEY idx_status (status, scheduled_for)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS business_verifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  business_name VARCHAR(150) NOT NULL,
  reg_number VARCHAR(60) NOT NULL,
  address VARCHAR(255) NOT NULL,
  id_document VARCHAR(255) NULL,
  status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  provider VARCHAR(30) NULL,
  provider_ref VARCHAR(100) NULL,
  note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME NULL,
  CONSTRAINT fk_bv_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS saved_locations (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  label VARCHAR(60) NOT NULL,
  address VARCHAR(255) NOT NULL,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  is_default_pickup TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_loc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_type ENUM('user','rider') NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  category ENUM('delivery','payment','system') NOT NULL DEFAULT 'system',
  title VARCHAR(120) NOT NULL,
  body VARCHAR(255) NOT NULL,
  data JSON NULL,
  read_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_owner (owner_type, owner_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sos_alerts (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NULL,
  user_id INT UNSIGNED NULL,
  rider_id INT UNSIGNED NULL,
  lat DECIMAL(10,7) NULL,
  lng DECIMAL(10,7) NULL,
  message VARCHAR(255) NULL,
  status ENUM('open','acknowledged','resolved') NOT NULL DEFAULT 'open',
  admin_id INT UNSIGNED NULL,
  resolution_note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS audit_logs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  entity VARCHAR(40) NULL,
  entity_id INT UNSIGNED NULL,
  details VARCHAR(500) NULL,
  ip VARCHAR(45) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_entity (entity, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- ── Seed: launch zones (Benin City live, Lagos zones gated) ──
INSERT IGNORE INTO zones (name, code, city, center_lat, center_lng, radius_km, is_live) VALUES
 ('Benin City', 'BEN', 'Benin City', 6.3350000, 5.6037000, 20, 1),
 ('Lekki', 'LEK', 'Lagos', 6.4474000, 3.4723000, 12, 0),
 ('Victoria Island', 'VIS', 'Lagos', 6.4281000, 3.4219000, 6, 0),
 ('Ikeja', 'IKJ', 'Lagos', 6.6018000, 3.3515000, 10, 0),
 ('Lagos Island', 'LIS', 'Lagos', 6.4549000, 3.3946000, 6, 0);

-- ── Seed: configurable business rules (editable in Admin → Settings) ──
INSERT IGNORE INTO settings (`key`, `value`) VALUES
 ('app_name', 'Dyspatch'),
 ('support_phone', '+2348000000000'),
 ('support_email', 'support@dyspatch.com.ng'),
 ('otp_length', '4'),
 ('otp_expiry_minutes', '30'),
 ('otp_max_attempts', '3'),
 ('otp_resend_seconds', '60'),
 ('matching_radius_km', '5'),
 ('accept_window_seconds', '45'),
 ('max_offer_rounds', '10'),
 ('commission_pct', '20'),
 ('pricing_model', 'min_fare'),
 ('base_fare_kobo', '50000'),
 ('per_km_kobo', '15000'),
 ('min_fare_kobo', '100000'),
 ('road_factor', '1.3'),
 ('avg_speed_kmh', '25'),
 ('mult_small', '1.0'),
 ('mult_medium', '1.2'),
 ('mult_large', '1.6'),
 ('mult_express', '1.5'),
 ('withdrawal_min_kobo', '50000'),
 ('withdrawal_cutoff_hour', '17'),
 ('withdrawal_fee_type', 'flat'),
 ('withdrawal_fee_value', '5000'),
 ('withdrawal_fee_tiers', '[{"upto":500000,"fee":2500},{"upto":5000000,"fee":5000},{"upto":null,"fee":10000}]'),
 ('withdrawal_provider', 'manual'),
 ('payment_provider', 'paystack'),
 ('kyc_provider', 'manual'),
 ('sms_driver', 'log'),
 ('tracking_link_expiry_hours', '24'),
 ('topup_bank_name', 'Stanbic IBTC Bank'),
 ('topup_account_name', 'DYSPATCH SMARTPAY'),
 ('topup_account_number', '8102437791'),
 ('paystack_public_key', ''),
 ('paystack_secret_key', ''),
 ('flutterwave_secret_key', ''),
 ('termii_api_key', ''),
 ('termii_sender_id', 'Dyspatch'),
 ('termii_channel', 'dnd'),
 ('prembly_app_id', ''),
 ('prembly_api_key', ''),
 ('smile_partner_id', ''),
 ('smile_api_key', ''),
 ('google_maps_key', ''),
 ('fcm_service_account', ''),
 ('push_enabled', '1'),
 ('email_enabled', '1'),
 ('smtp_host', ''),
 ('smtp_port', '587'),
 ('smtp_encryption', 'tls'),
 ('smtp_username', ''),
 ('smtp_password', ''),
 ('mail_from_email', 'no-reply@dyspatch.com.ng'),
 ('mail_from_name', 'Dyspatch'),
 ('admin_alert_email', ''),
 ('firebase_project_id', 'dyspatch-bc9cc');
