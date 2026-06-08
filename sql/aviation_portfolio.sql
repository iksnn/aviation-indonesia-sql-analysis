-- ============================================================
-- PORTOFOLIO DATA ANALYST: OPERASIONAL PENERBANGAN DOMESTIK INDONESIA
-- Tools: PostgreSQL | Fokus: Data Cleaning, JOIN, Subquery, CTE
-- Dataset: Simulasi data rute domestik Indonesia 2023
-- ============================================================

-- ============================================================
-- BAGIAN 1: SETUP SCHEMA & RAW DATA (DATA KOTOR)
-- ============================================================

DROP TABLE IF EXISTS raw_flights CASCADE;
DROP TABLE IF EXISTS raw_airports CASCADE;
DROP TABLE IF EXISTS raw_airlines CASCADE;
DROP TABLE IF EXISTS raw_passengers CASCADE;
DROP TABLE IF EXISTS raw_incidents CASCADE;

-- Tabel bandara (ada inkonsistensi kode, nama duplikat, spasi berlebih)
CREATE TABLE raw_airports (
    airport_id      SERIAL PRIMARY KEY,
    iata_code       VARCHAR(10),
    airport_name    TEXT,
    city            TEXT,
    province        TEXT,
    latitude        TEXT,     -- disimpan sebagai TEXT karena data kotor
    longitude       TEXT,
    elevation_ft    TEXT,
    is_international TEXT     -- 'yes','YES','1','true','Y' -- tidak konsisten
);

INSERT INTO raw_airports (iata_code, airport_name, city, province, latitude, longitude, elevation_ft, is_international) VALUES
('CGK', '  Soekarno-Hatta International Airport ', 'Tangerang', 'Banten', '-6.1256', '106.6559', '34', 'yes'),
('cgk', 'Soekarno Hatta Intl', 'tangerang', 'banten', '-6.1256', '106.6559', '34', 'YES'),  -- duplikat
('SUB', 'Juanda International Airport', 'Surabaya', 'Jawa Timur', '-7.3798', '112.7870', '9', '1'),
('DPS', 'Ngurah Rai International Airport', 'Denpasar', 'Bali', '-8.7482', '115.1670', '14', 'true'),
('UPG', 'Sultan Hasanuddin International Airport', 'Makassar', 'Sulawesi Selatan', '-5.0616', '119.5540', '47', 'Y'),
('BPN', 'Sultan Aji Muhammad Sulaiman Sepinggan Airport', 'Balikpapan', 'Kalimantan Timur', '-1.2683', '116.8944', '12', 'yes'),
('KNO', 'Kualanamu International Airport', 'Medan', 'Sumatera Utara', '3.6422', '98.8853', '23', 'yes'),
('PLM', 'Sultan Mahmud Badaruddin II Airport', 'Palembang', 'Sumatera Selatan', '-2.8983', '104.6997', '49', 'no'),
('PNK', 'Supadio Airport', 'Pontianak', 'Kalimantan Barat', '-0.1507', '109.4037', '10', 'no'),
('AMQ', 'Pattimura Airport', 'Ambon', 'Maluku', '-3.7103', '128.0890', '33', 'no'),
('MDC', 'Sam Ratulangi International Airport', 'Manado', 'Sulawesi Utara', '1.5493', '124.9261', '265', 'yes'),
('BTJ', 'Sultan Iskandar Muda Airport', 'Banda Aceh', 'Aceh', '5.5235', '95.4204', '62', 'yes'),
('BDO', 'Husein Sastranegara International Airport', 'Bandung', 'Jawa Barat', '-6.9006', '107.5763', '2436', 'YES'),
('JOG', 'Adisutjipto International Airport', 'Yogyakarta', 'DI Yogyakarta', '-7.7882', '110.4318', '350', 'yes'),
('SOC', 'Adisumarmo International Airport', 'Solo', 'Jawa Tengah', '-7.5159', '110.7575', '421', 'N/A'),  -- nilai aneh
('LOP', 'Lombok International Airport', 'Praya', 'NTB', '-8.7573', '116.2767', '319', 'yes'),
('TIM', 'Mozes Kilangin Airport', 'Timika', 'Papua', '-4.5283', '136.8870', '103', 'no'),
('BJW', null, 'Bajawa', 'NTT', null, null, null, 'no'),  -- data tidak lengkap
(null, 'Unknown Airport', null, null, null, null, null, null);  -- baris rusak

-- Tabel maskapai (ada typo, kode duplikat)
CREATE TABLE raw_airlines (
    airline_id      SERIAL PRIMARY KEY,
    iata_code       VARCHAR(5),
    airline_name    TEXT,
    alliance        TEXT,
    fleet_size      TEXT,   -- TEXT karena ada nilai '~120', 'sekitar 50'
    hub_airport     TEXT,
    status          TEXT
);

INSERT INTO raw_airlines (iata_code, airline_name, alliance, fleet_size, hub_airport, status) VALUES
('GA', 'Garuda Indonesia', 'SkyTeam', '142', 'CGK', 'active'),
('GA', 'Garuda Indonesia Airlines', 'SkyTeam', '142', 'CGK', 'ACTIVE'),  -- duplikat
('QG', 'Citilink Indonesia', 'None', '65', 'CGK', 'active'),
('ID', 'Batik Air', 'None', '~120', 'CGK', 'active'),         -- fleet kotor
('IW', 'Wings Air', 'None', '58', 'SUB', 'active'),
('IN', 'Nam Air', 'None', 'sekitar 15', 'PLM', 'active'),     -- fleet kotor
('SJ', 'Sriwijaya Air', 'None', '30', 'CGK', 'suspended'),
('XT', 'Indonesia AirAsia X', 'None', '10', 'DPS', 'active'),
('QZ', 'Indonesia AirAsia', 'None', '35', 'CGK', 'active'),
('IL', 'Trigana Air Service', NULL, '14', 'CGK', 'active'),
('MZ', '', 'None', '5', 'UPG', 'inactive'),  -- nama kosong
(null, 'Unknown Airline', null, null, null, null);  -- baris rusak

-- Tabel penerbangan (data kotor: delay negatif, tanggal aneh, referensi FK invalid)
CREATE TABLE raw_flights (
    flight_id           SERIAL PRIMARY KEY,
    flight_number       TEXT,
    airline_iata        TEXT,
    origin_iata         TEXT,
    destination_iata    TEXT,
    scheduled_dep       TEXT,    -- TEXT, format tidak konsisten
    scheduled_arr       TEXT,
    actual_dep          TEXT,
    actual_arr          TEXT,
    delay_minutes       TEXT,    -- ada nilai negatif, null, 'N/A'
    flight_status       TEXT,    -- inkonsistensi: 'On Time','on time','ONTIME','OT'
    aircraft_type       TEXT,
    passengers_onboard  TEXT,    -- ada nilai desimal aneh
    cargo_kg            TEXT
);

INSERT INTO raw_flights (flight_number, airline_iata, origin_iata, destination_iata,
    scheduled_dep, scheduled_arr, actual_dep, actual_arr,
    delay_minutes, flight_status, aircraft_type, passengers_onboard, cargo_kg) VALUES
('GA-401', 'GA', 'CGK', 'SUB', '2023-10-01 06:00', '2023-10-01 07:10', '2023-10-01 06:05', '2023-10-01 07:15', '5', 'On Time', 'B738', '162', '1200.5'),
('GA-402', 'GA', 'SUB', 'CGK', '2023-10-01 08:00', '2023-10-01 09:10', '2023-10-01 08:45', '2023-10-01 09:55', '45', 'Delayed', 'B738', '155', '980'),
('GA-403', 'GA', 'CGK', 'DPS', '2023-10-01 07:00', '2023-10-01 08:30', '2023-10-01 06:58', '2023-10-01 08:28', '-2', 'on time', 'B738', '162.5', '1500'),   -- delay negatif & status inkonsisten
('GA-700', 'GA', 'CGK', 'KNO', '2023-10-01 09:00', '2023-10-01 11:30', '2023-10-01 09:00', '2023-10-01 11:30', '0', 'ONTIME', 'B77W', '314', '3200'),
('QG-101', 'QG', 'CGK', 'SUB', '2023-10-01 06:30', '2023-10-01 07:40', '2023-10-01 07:15', '2023-10-01 08:25', '45', 'delayed', 'A320', '178', '0'),
('QG-201', 'QG', 'CGK', 'DPS', '2023-10-01 07:30', '2023-10-01 09:00', '2023-10-01 07:30', '2023-10-01 09:00', 'N/A', 'OT', 'A320', '178', '200'),  -- delay N/A & status 'OT'
('QG-301', 'QG', 'SUB', 'UPG', '2023-10-01 10:00', '2023-10-01 11:30', '2023-10-01 10:30', '2023-10-01 12:00', '30', 'Delayed', 'A320', '178', '350'),
('ID-601', 'ID', 'CGK', 'BPN', '2023-10-01 08:00', '2023-10-01 10:00', '2023-10-01 08:00', '2023-10-01 10:00', '0', 'On Time', 'B738', '189', '2100'),
('ID-602', 'ID', 'BPN', 'CGK', '2023-10-01 12:00', '2023-10-01 14:00', '2023-10-01 14:30', '2023-10-01 16:30', '150', 'Delayed', 'B738', '189', '1800'),
('ID-701', 'ID', 'CGK', 'MDC', '2023-10-01 07:00', '2023-10-01 10:00', null, null, null, 'Cancelled', 'B738', '0', '0'),
('IW-501', 'IW', 'SUB', 'TIM', '2023-10-01 09:00', '2023-10-01 13:30', '2023-10-01 09:20', '2023-10-01 13:55', '25', 'Delayed', 'AT76', '70', '500'),
('IW-502', 'IW', 'TIM', 'AMQ', '2023-10-01 15:00', '2023-10-01 16:30', '2023-10-01 15:00', '2023-10-01 16:25', '-5', 'on time', 'AT72', '64', '120'),  -- delay negatif
('SJ-001', 'SJ', 'CGK', 'PLM', '2023-10-01 08:00', '2023-10-01 09:00', null, null, null, 'Cancelled', 'B738', '0', '0'),  -- maskapai suspended
('GA-404', 'GA', 'CGK', 'JOG', '2023-10-01 10:00', '2023-10-01 11:00', '2023-10-01 10:00', '2023-10-01 11:00', '0', 'On Time', 'B73X', '177', '800'),
('QG-401', 'QG', 'DPS', 'LOP', '2023-10-01 11:00', '2023-10-01 11:45', '2023-10-01 11:30', '2023-10-01 12:15', '30', 'Delayed', 'A320', '178', '0'),
('GA-801', 'GA', 'CGK', 'AMQ', '2023-10-01 06:00', '2023-10-01 11:00', '2023-10-01 06:00', '2023-10-01 11:10', '10', 'On Time', 'B738', '162', '1800'),
('ZZ-999', 'ZZ', 'XXX', 'YYY', '2023-10-01 00:00', '2023-10-01 00:00', null, null, null, null, null, null, null),  -- referensi tidak valid
('GA-405', 'GA', 'CGK', 'SOC', '2023-10-01 11:00', '2023-10-01 12:15', '2023-10-01 11:00', '2023-10-01 12:15', '0', 'On Time', 'CRJ', '96', '400'),
('XT-101', 'XT', 'CGK', 'DPS', '2023-10-01 14:00', '2023-10-01 15:30', '2023-10-01 14:00', '2023-10-01 15:30', '0', 'On Time', 'A333', '377', '5000'),
('QG-501', 'QG', 'CGK', 'BTJ', '2023-10-01 08:00', '2023-10-01 10:30', '2023-10-01 09:10', '2023-10-01 11:40', '70', 'Delayed', 'A320', '178', '600');

-- Tabel penumpang (ada duplikat, gender inkonsistensi)
CREATE TABLE raw_passengers (
    passenger_id    SERIAL PRIMARY KEY,
    flight_id       INTEGER,
    full_name       TEXT,
    gender          TEXT,     -- 'L','P','Male','Female','M','F','laki','perempuan'
    nationality     TEXT,
    ticket_class    TEXT,     -- 'ekonomi','Economy','ECO','Business','BIZ','C'
    ticket_price    TEXT,     -- ada 'Rp 1.200.000', '1200000', '1,200,000'
    booking_date    TEXT,
    frequent_flyer  TEXT
);

INSERT INTO raw_passengers (flight_id, full_name, gender, nationality, ticket_class, ticket_price, booking_date, frequent_flyer) VALUES
(1, 'Budi Santoso', 'L', 'WNI', 'Ekonomi', 'Rp 850.000', '2023-09-15', 'YES'),
(1, 'Siti Rahayu', 'Perempuan', 'WNI', 'Economy', '850000', '2023-09-15', 'NO'),
(1, 'John Smith', 'Male', 'WNA', 'Business', 'Rp 2.500.000', '2023-09-10', 'YES'),
(1, 'Dewi Lestari', 'F', 'WNI', 'ECO', '850,000', '2023-09-20', 'no'),
(1, 'Ahmad Fauzi', 'M', 'WNI', 'ekonomi', '850000', '2023-09-18', 'YES'),
(2, 'Rina Wati', 'P', 'WNI', 'Ekonomi', 'Rp 900.000', '2023-09-14', 'YES'),
(2, 'Rina Wati', 'P', 'WNI', 'Ekonomi', 'Rp 900.000', '2023-09-14', 'YES'),   -- DUPLIKAT
(2, 'Hendra Gunawan', 'Laki', 'WNI', 'BIZ', '3500000', '2023-09-01', 'YES'),
(3, 'Maria Santos', 'Female', 'WNA', 'Economy', '1200000', '2023-09-12', 'NO'),
(3, 'Agus Setiawan', 'L', 'WNI', 'ekonomi', 'Rp 1.200.000', '2023-09-16', 'YES'),
(4, 'Yusuf Ibrahim', 'M', 'WNI', 'Business', '4500000', '2023-08-30', 'YES'),
(5, 'Fitria Handayani', 'Perempuan', 'WNI', 'Economy', '750000', '2023-09-22', 'NO'),
(5, 'Reza Permana', 'Male', 'WNI', 'ECO', '750,000', '2023-09-22', 'NO'),
(8, 'Tono Subroto', 'L', 'WNI', 'C', 'Rp 5.000.000', '2023-09-05', 'YES'),    -- kelas 'C' = Business
(9, 'Lisa Kurniawan', 'F', 'WNI', 'Ekonomi', '1900000', '2023-09-20', 'no'),
(11, 'Pak Bambang', 'Laki-Laki', 'WNI', 'ekonomi', '1,100,000', '2023-09-18', 'NO');

-- Tabel insiden keamanan penerbangan
CREATE TABLE raw_incidents (
    incident_id     SERIAL PRIMARY KEY,
    flight_id       INTEGER,
    incident_date   TEXT,
    incident_type   TEXT,
    severity        TEXT,     -- 'Low','Medium','High','CRITICAL','1','2','3','4'
    description     TEXT,
    resolved        TEXT      -- 'yes','no','true','false','1','0'
);

INSERT INTO raw_incidents (flight_id, incident_date, incident_type, severity, description, resolved) VALUES
(2, '2023-10-01', 'Technical', 'Medium', 'Landing gear sensor malfunction, resolved pre-departure', 'yes'),
(5, '2023-10-01', 'Weather', 'Low', 'Turbulence encountered at FL280', 'yes'),
(9, '2023-10-01', 'Medical', '2', 'Passenger required emergency oxygen', 'true'),   -- severity angka
(10, '2023-10-01', 'Technical', 'CRITICAL', 'Engine warning light, flight cancelled', '1'),
(12, '2023-10-01', 'Bird Strike', 'High', 'Bird strike on approach to AMQ', 'yes'),
(16, '2023-10-01', 'Weather', 'Low', 'Minor turbulence over Banda Sea', 'yes'),
(2, '2023-10-01', 'Technical', 'Medium', 'Landing gear sensor malfunction, resolved pre-departure', 'yes'),  -- duplikat
(99, '2023-10-01', 'Unknown', 'Low', 'Incident dengan flight_id tidak ada', 'no');  -- FK invalid


-- ============================================================
-- BAGIAN 2: DATA CLEANING
-- ============================================================

-- -------------------------------------------------------
-- 2A. CLEANING AIRPORTS
-- -------------------------------------------------------

DROP TABLE IF EXISTS clean_airports;

CREATE TABLE clean_airports AS
WITH ranked AS (
    SELECT *,
        -- Normalisasi kode IATA ke uppercase & trim
        UPPER(TRIM(iata_code)) AS iata_clean,
        UPPER(TRIM(city))      AS city_clean,
        UPPER(TRIM(province))  AS province_clean,
        TRIM(airport_name)     AS name_clean,

        -- Normalisasi is_international ke BOOLEAN
        CASE
            WHEN LOWER(TRIM(is_international)) IN ('yes','1','true','y') THEN TRUE
            WHEN LOWER(TRIM(is_international)) IN ('no','0','false','n') THEN FALSE
            ELSE NULL
        END AS is_intl_clean,

        -- Konversi koordinat ke numerik (bersihkan jika tidak valid)
        CASE WHEN latitude  ~ '^-?[0-9]+\.?[0-9]*$' THEN latitude::NUMERIC  ELSE NULL END AS lat_clean,
        CASE WHEN longitude ~ '^-?[0-9]+\.?[0-9]*$' THEN longitude::NUMERIC ELSE NULL END AS lon_clean,
        CASE WHEN elevation_ft ~ '^[0-9]+$' THEN elevation_ft::INTEGER ELSE NULL END AS elev_clean,

        -- Tandai duplikat berdasarkan IATA code (ambil record pertama)
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(iata_code))
            ORDER BY airport_id
        ) AS rn
    FROM raw_airports
    WHERE iata_code IS NOT NULL
      AND iata_code != ''
      AND airport_name IS NOT NULL
)
SELECT
    airport_id,
    iata_clean          AS iata_code,
    name_clean          AS airport_name,
    city_clean          AS city,
    province_clean      AS province,
    lat_clean           AS latitude,
    lon_clean           AS longitude,
    elev_clean          AS elevation_ft,
    is_intl_clean       AS is_international
FROM ranked
WHERE rn = 1;   -- buang duplikat

-- -------------------------------------------------------
-- 2B. CLEANING AIRLINES
-- -------------------------------------------------------

DROP TABLE IF EXISTS clean_airlines;

CREATE TABLE clean_airlines AS
WITH parsed AS (
    SELECT *,
        UPPER(TRIM(iata_code))  AS iata_clean,
        TRIM(airline_name)      AS name_clean,
        LOWER(TRIM(status))     AS status_clean,

        -- Ekstrak angka dari fleet_size (hapus ~, 'sekitar', spasi)
        CASE
            WHEN fleet_size ~ '^[0-9]+$' THEN fleet_size::INTEGER
            WHEN fleet_size ~ '[0-9]+' THEN
                (REGEXP_MATCH(fleet_size, '[0-9]+'))[1]::INTEGER
            ELSE NULL
        END AS fleet_size_clean,

        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(iata_code))
            ORDER BY airline_id
        ) AS rn
    FROM raw_airlines
    WHERE iata_code IS NOT NULL
      AND airline_name IS NOT NULL
      AND TRIM(airline_name) != ''
)
SELECT
    airline_id,
    iata_clean          AS iata_code,
    name_clean          AS airline_name,
    COALESCE(alliance, 'None') AS alliance,
    fleet_size_clean    AS fleet_size,
    UPPER(TRIM(hub_airport)) AS hub_airport,
    status_clean        AS status
FROM parsed
WHERE rn = 1;

-- -------------------------------------------------------
-- 2C. CLEANING FLIGHTS
-- -------------------------------------------------------

DROP TABLE IF EXISTS clean_flights;

CREATE TABLE clean_flights AS
WITH normalized AS (
    SELECT
        f.flight_id,
        UPPER(TRIM(f.flight_number))    AS flight_number,
        UPPER(TRIM(f.airline_iata))     AS airline_iata,
        UPPER(TRIM(f.origin_iata))      AS origin_iata,
        UPPER(TRIM(f.destination_iata)) AS destination_iata,

        -- Normalisasi status penerbangan
        CASE
            WHEN LOWER(TRIM(f.flight_status)) IN ('on time','ontime','ot') THEN 'On Time'
            WHEN LOWER(TRIM(f.flight_status)) IN ('delayed','delay')       THEN 'Delayed'
            WHEN LOWER(TRIM(f.flight_status)) = 'cancelled'                THEN 'Cancelled'
            ELSE 'Unknown'
        END AS flight_status,

        -- Bersihkan delay: negatif → 0, N/A → NULL
        CASE
            WHEN f.delay_minutes ~ '^-?[0-9]+$' AND f.delay_minutes::INTEGER < 0 THEN 0
            WHEN f.delay_minutes ~ '^[0-9]+$' THEN f.delay_minutes::INTEGER
            ELSE NULL
        END AS delay_minutes,

        -- Parse timestamp
        TO_TIMESTAMP(f.scheduled_dep, 'YYYY-MM-DD HH24:MI') AS scheduled_dep,
        TO_TIMESTAMP(f.scheduled_arr, 'YYYY-MM-DD HH24:MI') AS scheduled_arr,
        CASE WHEN f.actual_dep IS NOT NULL
             THEN TO_TIMESTAMP(f.actual_dep, 'YYYY-MM-DD HH24:MI') END AS actual_dep,
        CASE WHEN f.actual_arr IS NOT NULL
             THEN TO_TIMESTAMP(f.actual_arr, 'YYYY-MM-DD HH24:MI') END AS actual_arr,

        -- Bersihkan penumpang dan kargo
        CASE WHEN f.passengers_onboard ~ '^[0-9]+\.?[0-9]*$'
             THEN ROUND(f.passengers_onboard::NUMERIC)::INTEGER
             ELSE NULL END AS passengers_onboard,
        CASE WHEN f.cargo_kg ~ '^[0-9]+\.?[0-9]*$'
             THEN f.cargo_kg::NUMERIC
             ELSE NULL END AS cargo_kg

    FROM raw_flights f
    -- Hanya flight dengan airline dan airport yang valid (INNER JOIN untuk filter)
    INNER JOIN clean_airlines  ca ON UPPER(TRIM(f.airline_iata))     = ca.iata_code
    INNER JOIN clean_airports  co ON UPPER(TRIM(f.origin_iata))      = co.iata_code
    INNER JOIN clean_airports  cd ON UPPER(TRIM(f.destination_iata)) = cd.iata_code
    -- Exclude maskapai yang suspended/inactive
    WHERE ca.status = 'active'
)
SELECT * FROM normalized;

-- -------------------------------------------------------
-- 2D. CLEANING PASSENGERS
-- -------------------------------------------------------

DROP TABLE IF EXISTS clean_passengers;

CREATE TABLE clean_passengers AS
WITH deduped AS (
    SELECT *,
        -- Normalisasi gender
        CASE
            WHEN LOWER(gender) IN ('l','m','male','laki','laki-laki') THEN 'Male'
            WHEN LOWER(gender) IN ('p','f','female','perempuan')      THEN 'Female'
            ELSE 'Unknown'
        END AS gender_clean,

        -- Normalisasi kelas tiket
        CASE
            WHEN LOWER(ticket_class) IN ('ekonomi','economy','eco') THEN 'Economy'
            WHEN LOWER(ticket_class) IN ('business','biz','c')      THEN 'Business'
            WHEN LOWER(ticket_class) = 'first'                       THEN 'First'
            ELSE 'Economy'
        END AS ticket_class_clean,

        -- Bersihkan harga tiket: hapus 'Rp ', titik, koma
        REGEXP_REPLACE(
            REGEXP_REPLACE(ticket_price, 'Rp\s*', '', 'gi'),
            '[.,]', '', 'g'
        )::BIGINT AS ticket_price_clean,

        -- Normalisasi frequent_flyer
        CASE WHEN LOWER(frequent_flyer) IN ('yes','true','1') THEN TRUE
             ELSE FALSE END AS is_frequent_flyer,

        -- Hapus duplikat (nama + flight + booking_date sama)
        ROW_NUMBER() OVER (
            PARTITION BY flight_id, LOWER(TRIM(full_name)), booking_date
            ORDER BY passenger_id
        ) AS rn

    FROM raw_passengers
    WHERE full_name IS NOT NULL
      AND TRIM(full_name) != ''
      AND flight_id IS NOT NULL
)
SELECT
    passenger_id,
    flight_id,
    INITCAP(TRIM(full_name))  AS full_name,
    gender_clean               AS gender,
    UPPER(TRIM(nationality))   AS nationality,
    ticket_class_clean         AS ticket_class,
    ticket_price_clean         AS ticket_price_idr,
    booking_date::DATE         AS booking_date,
    is_frequent_flyer
FROM deduped
WHERE rn = 1;

-- -------------------------------------------------------
-- 2E. CLEANING INCIDENTS
-- -------------------------------------------------------

DROP TABLE IF EXISTS clean_incidents;

CREATE TABLE clean_incidents AS
WITH deduped AS (
    SELECT *,
        -- Normalisasi severity
        CASE
            WHEN UPPER(severity) IN ('LOW','1')      THEN 'Low'
            WHEN UPPER(severity) IN ('MEDIUM','2')   THEN 'Medium'
            WHEN UPPER(severity) IN ('HIGH','3')     THEN 'High'
            WHEN UPPER(severity) IN ('CRITICAL','4') THEN 'Critical'
            ELSE 'Unknown'
        END AS severity_clean,

        -- Normalisasi resolved
        CASE
            WHEN LOWER(resolved) IN ('yes','true','1') THEN TRUE
            ELSE FALSE
        END AS resolved_clean,

        -- Hapus duplikat
        ROW_NUMBER() OVER (
            PARTITION BY flight_id, incident_type, LOWER(description)
            ORDER BY incident_id
        ) AS rn

    FROM raw_incidents
    WHERE flight_id IS NOT NULL
)
SELECT
    i.incident_id,
    i.flight_id,
    i.incident_date::DATE   AS incident_date,
    INITCAP(i.incident_type) AS incident_type,
    i.severity_clean         AS severity,
    i.description,
    i.resolved_clean         AS resolved
FROM deduped i
-- Hanya insiden pada flight yang valid
INNER JOIN clean_flights cf ON i.flight_id = cf.flight_id
WHERE i.rn = 1;


-- ============================================================
-- BAGIAN 3: ANALISIS - JOIN QUERIES
-- ============================================================

-- 3A. QUERY JOIN: Informasi lengkap setiap penerbangan
-- (Multi-table JOIN: flights + airlines + airports asal + airports tujuan)
SELECT
    cf.flight_number,
    ca.airline_name,
    ao.airport_name                 AS origin_airport,
    ao.city                         AS origin_city,
    ad.airport_name                 AS dest_airport,
    ad.city                         AS dest_city,
    cf.scheduled_dep,
    cf.flight_status,
    COALESCE(cf.delay_minutes, 0)   AS delay_minutes,
    cf.passengers_onboard,
    cf.cargo_kg
FROM clean_flights cf
JOIN clean_airlines  ca ON cf.airline_iata = ca.iata_code
JOIN clean_airports  ao ON cf.origin_iata  = ao.iata_code
JOIN clean_airports  ad ON cf.destination_iata = ad.iata_code
ORDER BY cf.scheduled_dep;


-- 3B. LEFT JOIN: Semua penerbangan termasuk yang tidak ada insiden
SELECT
    cf.flight_number,
    ca.airline_name,
    cf.origin_iata || ' → ' || cf.destination_iata AS route,
    cf.flight_status,
    ci.incident_type,
    ci.severity,
    COALESCE(ci.resolved::TEXT, 'No Incident') AS incident_status
FROM clean_flights cf
JOIN  clean_airlines ca ON cf.airline_iata = ca.iata_code
LEFT JOIN clean_incidents ci ON cf.flight_id = ci.flight_id
ORDER BY cf.flight_number;


-- 3C. Pendapatan per maskapai dengan detail penumpang (JOIN 4 tabel)
SELECT
    ca.airline_name,
    COUNT(DISTINCT cf.flight_id)        AS total_flights,
    COUNT(cp.passenger_id)              AS total_passengers,
    SUM(cp.ticket_price_idr)            AS total_revenue_idr,
    AVG(cp.ticket_price_idr)::BIGINT    AS avg_ticket_price,
    SUM(CASE WHEN cp.ticket_class = 'Business' THEN 1 ELSE 0 END) AS business_pax,
    SUM(CASE WHEN cp.ticket_class = 'Economy'  THEN 1 ELSE 0 END) AS economy_pax
FROM clean_airlines ca
JOIN clean_flights   cf ON ca.iata_code   = cf.airline_iata
JOIN clean_passengers cp ON cf.flight_id  = cp.flight_id
GROUP BY ca.airline_name
ORDER BY total_revenue_idr DESC;


-- ============================================================
-- BAGIAN 4: ANALISIS - SUBQUERIES
-- ============================================================

-- 4A. SUBQUERY dalam WHERE: Penerbangan dengan delay lebih tinggi dari rata-rata
SELECT
    cf.flight_number,
    ca.airline_name,
    cf.origin_iata || ' → ' || cf.destination_iata AS route,
    cf.delay_minutes,
    ROUND(
        (SELECT AVG(delay_minutes) FROM clean_flights WHERE flight_status = 'Delayed'),
    1) AS avg_delay_all
FROM clean_flights cf
JOIN clean_airlines ca ON cf.airline_iata = ca.iata_code
WHERE cf.flight_status = 'Delayed'
  AND cf.delay_minutes > (
      SELECT AVG(delay_minutes)
      FROM clean_flights
      WHERE flight_status = 'Delayed'
  )
ORDER BY cf.delay_minutes DESC;


-- 4B. SUBQUERY dalam FROM (Derived Table): Rangking maskapai berdasarkan ketepatan waktu
SELECT
    airline_summary.airline_name,
    airline_summary.total_flights,
    airline_summary.on_time_flights,
    ROUND(airline_summary.on_time_pct, 1) AS on_time_percentage,
    RANK() OVER (ORDER BY airline_summary.on_time_pct DESC) AS punctuality_rank
FROM (
    SELECT
        ca.airline_name,
        COUNT(*)                            AS total_flights,
        SUM(CASE WHEN cf.flight_status = 'On Time' THEN 1 ELSE 0 END) AS on_time_flights,
        100.0 * SUM(CASE WHEN cf.flight_status = 'On Time' THEN 1 ELSE 0 END)
              / COUNT(*) AS on_time_pct
    FROM clean_flights cf
    JOIN clean_airlines ca ON cf.airline_iata = ca.iata_code
    GROUP BY ca.airline_name
) AS airline_summary
ORDER BY punctuality_rank;


-- 4C. CORRELATED SUBQUERY: Penerbangan dengan insiden, tampilkan total insiden maskapai
SELECT
    cf.flight_number,
    ca.airline_name,
    ci.incident_type,
    ci.severity,
    (
        SELECT COUNT(*)
        FROM clean_incidents ci2
        JOIN clean_flights   cf2 ON ci2.flight_id  = cf2.flight_id
        WHERE cf2.airline_iata = cf.airline_iata
    ) AS total_airline_incidents
FROM clean_incidents ci
JOIN clean_flights   cf ON ci.flight_id  = cf.flight_id
JOIN clean_airlines  ca ON cf.airline_iata = ca.iata_code
ORDER BY total_airline_incidents DESC, ci.severity;


-- ============================================================
-- BAGIAN 5: ANALISIS - CTEs (Common Table Expressions)
-- ============================================================

-- 5A. CTE Berantai: Analisis performa rute penerbangan
WITH route_stats AS (
    -- CTE 1: Hitung statistik dasar per rute
    SELECT
        cf.origin_iata,
        cf.destination_iata,
        cf.origin_iata || ' → ' || cf.destination_iata AS route,
        COUNT(*)                            AS total_flights,
        AVG(COALESCE(cf.delay_minutes, 0)) AS avg_delay,
        SUM(cf.passengers_onboard)          AS total_pax,
        SUM(cf.cargo_kg)                    AS total_cargo_kg,
        SUM(CASE WHEN cf.flight_status = 'On Time'  THEN 1 ELSE 0 END) AS on_time_cnt,
        SUM(CASE WHEN cf.flight_status = 'Delayed'  THEN 1 ELSE 0 END) AS delayed_cnt,
        SUM(CASE WHEN cf.flight_status = 'Cancelled'THEN 1 ELSE 0 END) AS cancelled_cnt
    FROM clean_flights cf
    GROUP BY cf.origin_iata, cf.destination_iata
),
route_with_airports AS (
    -- CTE 2: Gabungkan dengan nama bandara
    SELECT
        rs.*,
        ao.airport_name AS origin_name,
        ao.city         AS origin_city,
        ao.province     AS origin_province,
        ad.airport_name AS dest_name,
        ad.city         AS dest_city,
        ao.is_international AS origin_is_intl,
        ad.is_international AS dest_is_intl
    FROM route_stats rs
    JOIN clean_airports ao ON rs.origin_iata      = ao.iata_code
    JOIN clean_airports ad ON rs.destination_iata = ad.iata_code
),
route_classified AS (
    -- CTE 3: Klasifikasi rute berdasarkan performa
    SELECT *,
        ROUND(100.0 * on_time_cnt / NULLIF(total_flights, 0), 1) AS on_time_pct,
        CASE
            WHEN avg_delay <= 5  AND 100.0 * on_time_cnt / total_flights >= 80 THEN 'Excellent'
            WHEN avg_delay <= 20 AND 100.0 * on_time_cnt / total_flights >= 60 THEN 'Good'
            WHEN avg_delay <= 45 THEN 'Fair'
            ELSE 'Poor'
        END AS performance_grade,
        CASE
            WHEN origin_is_intl AND dest_is_intl THEN 'Intl–Intl'
            WHEN origin_is_intl OR  dest_is_intl THEN 'Intl–Dom'
            ELSE 'Dom–Dom'
        END AS route_type
    FROM route_with_airports
)
SELECT
    route,
    origin_city || ', ' || origin_province  AS origin,
    dest_city,
    route_type,
    total_flights,
    ROUND(avg_delay, 1)     AS avg_delay_min,
    on_time_pct,
    performance_grade,
    total_pax,
    ROUND(total_cargo_kg)   AS total_cargo_kg
FROM route_classified
ORDER BY performance_grade, avg_delay DESC;


-- 5B. RECURSIVE CTE: Hierarki hub dan spoke bandara
WITH RECURSIVE hub_network AS (
    -- Base: Hub utama (Soekarno-Hatta)
    SELECT
        iata_code,
        airport_name,
        city,
        0 AS hub_level,
        iata_code AS hub_root,
        ARRAY[iata_code] AS path
    FROM clean_airports
    WHERE iata_code = 'CGK'

    UNION ALL

    -- Recursive: Bandara yang terhubung langsung dengan flight dari hub
    SELECT
        ca.iata_code,
        ca.airport_name,
        ca.city,
        hn.hub_level + 1,
        hn.hub_root,
        hn.path || ca.iata_code
    FROM hub_network hn
    JOIN clean_flights cf ON cf.origin_iata = hn.iata_code
    JOIN clean_airports ca ON ca.iata_code = cf.destination_iata
    WHERE NOT ca.iata_code = ANY(hn.path)
      AND hn.hub_level < 2   -- maksimal 2 hop
)
SELECT
    hub_level,
    REPEAT('  ', hub_level) || iata_code AS indented_code,
    airport_name,
    city,
    hub_root
FROM hub_network
GROUP BY hub_level, iata_code, airport_name, city, hub_root
ORDER BY hub_level, iata_code;


-- 5C. CTE + Window Function: Analisis penumpang premium per penerbangan
WITH passenger_segments AS (
    SELECT
        cp.flight_id,
        COUNT(*)                                        AS total_pax,
        SUM(cp.ticket_price_idr)                        AS total_revenue,
        SUM(CASE WHEN cp.ticket_class = 'Business' THEN cp.ticket_price_idr ELSE 0 END) AS business_rev,
        SUM(CASE WHEN cp.is_frequent_flyer THEN 1 ELSE 0 END) AS ff_pax,
        ROUND(AVG(cp.ticket_price_idr))                 AS avg_ticket
    FROM clean_passengers cp
    GROUP BY cp.flight_id
),
flight_enriched AS (
    SELECT
        cf.flight_number,
        ca.airline_name,
        cf.origin_iata || ' → ' || cf.destination_iata  AS route,
        cf.flight_status,
        ps.total_pax,
        ps.total_revenue,
        ps.business_rev,
        ps.ff_pax,
        ps.avg_ticket,
        -- Window functions untuk perbandingan
        RANK() OVER (ORDER BY ps.total_revenue DESC)     AS revenue_rank,
        ROUND(100.0 * ps.business_rev / NULLIF(ps.total_revenue,0), 1) AS business_rev_pct,
        SUM(ps.total_revenue) OVER ()                    AS grand_total_revenue,
        ROUND(100.0 * ps.total_revenue / SUM(ps.total_revenue) OVER (), 1) AS revenue_share_pct
    FROM clean_flights cf
    JOIN clean_airlines ca ON cf.airline_iata = ca.iata_code
    JOIN passenger_segments ps ON cf.flight_id = ps.flight_id
)
SELECT
    flight_number,
    airline_name,
    route,
    flight_status,
    total_pax,
    total_revenue         AS total_revenue_idr,
    business_rev_pct      AS pct_from_business,
    ff_pax,
    revenue_rank,
    revenue_share_pct     AS pct_of_total_revenue
FROM flight_enriched
ORDER BY revenue_rank;


-- ============================================================
-- BAGIAN 6: ANALISIS LANJUTAN - BUSINESS INSIGHTS
-- ============================================================

-- 6A. Dashboard: KPI Ringkasan Operasional
WITH kpi AS (
    SELECT
        COUNT(DISTINCT cf.flight_id)                            AS total_flights,
        COUNT(DISTINCT cf.airline_iata)                         AS total_airlines,
        COUNT(DISTINCT cf.origin_iata || cf.destination_iata)   AS total_routes,
        SUM(cf.passengers_onboard)                              AS total_pax,
        ROUND(AVG(COALESCE(cf.delay_minutes,0)), 1)             AS avg_delay_min,
        ROUND(100.0 * SUM(CASE WHEN cf.flight_status='On Time'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS on_time_pct,
        ROUND(100.0 * SUM(CASE WHEN cf.flight_status='Delayed'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS delayed_pct,
        ROUND(100.0 * SUM(CASE WHEN cf.flight_status='Cancelled'THEN 1 ELSE 0 END)/COUNT(*), 1) AS cancelled_pct,
        SUM(cf.cargo_kg)                                        AS total_cargo_kg
    FROM clean_flights cf
)
SELECT * FROM kpi;


-- 6B. Bandara tersibuk berdasarkan pergerakan pesawat
WITH airport_movements AS (
    SELECT iata_code, airport_name, city, 'Departures' AS direction,
           COUNT(*) AS movements
    FROM clean_airports ap
    JOIN clean_flights cf ON ap.iata_code = cf.origin_iata
    GROUP BY iata_code, airport_name, city
    UNION ALL
    SELECT iata_code, airport_name, city, 'Arrivals',
           COUNT(*)
    FROM clean_airports ap
    JOIN clean_flights cf ON ap.iata_code = cf.destination_iata
    GROUP BY iata_code, airport_name, city
)
SELECT
    iata_code,
    airport_name,
    city,
    SUM(movements)                              AS total_movements,
    SUM(CASE WHEN direction='Departures' THEN movements ELSE 0 END) AS departures,
    SUM(CASE WHEN direction='Arrivals'   THEN movements ELSE 0 END) AS arrivals,
    RANK() OVER (ORDER BY SUM(movements) DESC)  AS busiest_rank
FROM airport_movements
GROUP BY iata_code, airport_name, city
ORDER BY total_movements DESC;


-- 6C. Safety Analysis: Insiden berdasarkan maskapai dan severity
WITH incident_summary AS (
    SELECT
        ca.airline_name,
        ci.severity,
        COUNT(*) AS incident_count
    FROM clean_incidents ci
    JOIN clean_flights cf ON ci.flight_id = cf.flight_id
    JOIN clean_airlines ca ON cf.airline_iata = ca.iata_code
    GROUP BY ca.airline_name, ci.severity
),
severity_pivot AS (
    SELECT
        airline_name,
        SUM(CASE WHEN severity = 'Low'      THEN incident_count ELSE 0 END) AS low_incidents,
        SUM(CASE WHEN severity = 'Medium'   THEN incident_count ELSE 0 END) AS medium_incidents,
        SUM(CASE WHEN severity = 'High'     THEN incident_count ELSE 0 END) AS high_incidents,
        SUM(CASE WHEN severity = 'Critical' THEN incident_count ELSE 0 END) AS critical_incidents,
        SUM(incident_count)                                                   AS total_incidents
    FROM incident_summary
    GROUP BY airline_name
)
SELECT *,
    RANK() OVER (ORDER BY critical_incidents DESC, high_incidents DESC) AS safety_risk_rank
FROM severity_pivot
ORDER BY safety_risk_rank;


-- ============================================================
-- RINGKASAN DATA QUALITY REPORT
-- ============================================================

SELECT 'airports'  AS table_name, COUNT(*) AS raw_rows, (SELECT COUNT(*) FROM clean_airports)  AS clean_rows, COUNT(*) - (SELECT COUNT(*) FROM clean_airports)  AS removed FROM raw_airports
UNION ALL
SELECT 'airlines',  COUNT(*), (SELECT COUNT(*) FROM clean_airlines),  COUNT(*) - (SELECT COUNT(*) FROM clean_airlines)  FROM raw_airlines
UNION ALL
SELECT 'flights',   COUNT(*), (SELECT COUNT(*) FROM clean_flights),   COUNT(*) - (SELECT COUNT(*) FROM clean_flights)   FROM raw_flights
UNION ALL
SELECT 'passengers',COUNT(*), (SELECT COUNT(*) FROM clean_passengers),COUNT(*) - (SELECT COUNT(*) FROM clean_passengers) FROM raw_passengers
UNION ALL
SELECT 'incidents', COUNT(*), (SELECT COUNT(*) FROM clean_incidents), COUNT(*) - (SELECT COUNT(*) FROM clean_incidents)  FROM raw_incidents;