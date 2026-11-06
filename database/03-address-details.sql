USE food_delivery_db;

ALTER TABLE addresses
  ADD COLUMN address_type ENUM('HOME', 'WORK', 'OTHER') NOT NULL DEFAULT 'HOME' AFTER user_id,
  ADD COLUMN recipient_name VARCHAR(100) NULL AFTER address_type,
  ADD COLUMN phone VARCHAR(20) NULL AFTER recipient_name,
  ADD COLUMN landmark VARCHAR(255) NULL AFTER address_line2,
  ADD COLUMN latitude DECIMAL(10, 7) NULL AFTER postal_code,
  ADD COLUMN longitude DECIMAL(10, 7) NULL AFTER latitude;
