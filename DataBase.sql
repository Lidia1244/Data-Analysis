--
-- PostgreSQL database cluster dump
--

-- Started on 2026-07-16 17:12:56

\restrict wuK8qGKlMWCe9xNU6ndwe5fwka7sbdoqv5ufBrIKc7ITlowIDPBvmry7cGszdb8

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS;

--
-- User Configurations
--








\unrestrict wuK8qGKlMWCe9xNU6ndwe5fwka7sbdoqv5ufBrIKc7ITlowIDPBvmry7cGszdb8

--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

\restrict oQkQzVJJ5AJMcNiQJCaz4tNavpvv9egeqLLCINtDfU9Yapf6lsP5wMfX7iqc7H0

-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

-- Started on 2026-07-16 17:12:56

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Completed on 2026-07-16 17:12:57

--
-- PostgreSQL database dump complete
--

\unrestrict oQkQzVJJ5AJMcNiQJCaz4tNavpvv9egeqLLCINtDfU9Yapf6lsP5wMfX7iqc7H0

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

\restrict MUGG9n3nZlmxSZhX2NIXcC3gwfcKP8hRqnV15RTD3M2Tlfah1PgcvMobdZ4zKwm

-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

-- Started on 2026-07-16 17:12:57

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 9 (class 2615 OID 16393)
-- Name: dds; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA dds;


ALTER SCHEMA dds OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 16392)
-- Name: md; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA md;


ALTER SCHEMA md OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 16391)
-- Name: ods; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ods;


ALTER SCHEMA ods OWNER TO postgres;

--
-- TOC entry 6 (class 2615 OID 16390)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO postgres;

--
-- TOC entry 347 (class 1255 OID 17447)
-- Name: load_dds_campaign_clients(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_campaign_clients() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_id + client_id + card_id
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_id, client_id, card_id
        FROM ods.campaign_clients
        GROUP BY campaign_id, client_id, card_id
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в ods.campaign_clients по campaign_id + client_id + card_id: % записей', v_duplicates;
    END IF;

    INSERT INTO dds.fact_campaign_clients (
        campaign_id,
        client_id,
        card_id,
        enrollment_dttm,
        status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dc.campaign_id,
        dcl.client_id,
        dcd.card_id,
        o.enrollment_dttm,
        o.status,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.campaign_clients o
    -- находим campaign_id через campaign_name
    LEFT JOIN ods.campaigns oc
           ON oc.campaign_id = o.campaign_id
    LEFT JOIN dds.dim_campaigns dc
           ON LOWER(TRIM(dc.campaign_name)) = LOWER(TRIM(oc.campaign_name))
          AND dc.start_dt = oc.start_dt
    -- находим client_id через full_name
    LEFT JOIN ods.clients ocl
           ON ocl.client_id = o.client_id
    LEFT JOIN dds.dim_clients dcl
           ON LOWER(TRIM(dcl.full_name)) = LOWER(TRIM(ocl.full_name))
    -- находим card_id через card_number_hash
    LEFT JOIN ods.cards ocd
           ON ocd.card_id = o.card_id
    LEFT JOIN dds.dim_cards dcd
           ON dcd.card_number_hash = ocd.card_number_hash
    WHERE dc.campaign_id IS NOT NULL
      AND dcl.client_id  IS NOT NULL
      AND dcd.card_id    IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.fact_campaign_clients f
          WHERE f.campaign_id = dc.campaign_id
            AND f.client_id   = dcl.client_id
            AND f.card_id     = dcd.card_id
      )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_campaign_clients() OWNER TO postgres;

--
-- TOC entry 348 (class 1255 OID 17448)
-- Name: load_dds_campaign_rewards(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_campaign_rewards() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_id + client_id + transaction_id
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_id, client_id, transaction_id
        FROM ods.campaign_rewards
        GROUP BY campaign_id, client_id, transaction_id
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в ods.campaign_rewards по campaign_id + client_id + transaction_id: % записей', v_duplicates;
    END IF;

    INSERT INTO dds.fact_campaign_rewards (
        campaign_id,
        client_id,
        transaction_id,
        reward_amount,
        reward_dt,
        reward_status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dc.campaign_id,
        dcl.client_id,
        ft.transaction_id,
        o.reward_amount,
        o.reward_dt,
        o.reward_status,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.campaign_rewards o
    -- находим campaign_id через campaign_name
    LEFT JOIN ods.campaigns oc
           ON oc.campaign_id = o.campaign_id
    LEFT JOIN dds.dim_campaigns dc
           ON LOWER(TRIM(dc.campaign_name)) = LOWER(TRIM(oc.campaign_name))
          AND dc.start_dt = oc.start_dt
    -- находим client_id через full_name
    LEFT JOIN ods.clients ocl
           ON ocl.client_id = o.client_id
    LEFT JOIN dds.dim_clients dcl
           ON LOWER(TRIM(dcl.full_name)) = LOWER(TRIM(ocl.full_name))
    -- находим transaction_id через dds.fact_transactions
    LEFT JOIN ods.transactions ot
           ON ot.transaction_id = o.transaction_id
    LEFT JOIN ods.cards ocd
           ON ocd.card_id = ot.card_id
    LEFT JOIN dds.dim_cards dcd
           ON dcd.card_number_hash = ocd.card_number_hash
    LEFT JOIN dds.fact_transactions ft
           ON ft.card_id          = dcd.card_id
          AND ft.transaction_dttm = ot.transaction_dttm
    WHERE dc.campaign_id   IS NOT NULL
      AND dcl.client_id    IS NOT NULL
      AND ft.transaction_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.fact_campaign_rewards f
          WHERE f.campaign_id    = dc.campaign_id
            AND f.client_id      = dcl.client_id
            AND f.transaction_id = ft.transaction_id
      )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_campaign_rewards() OWNER TO postgres;

--
-- TOC entry 341 (class 1255 OID 17446)
-- Name: load_dds_campaigns(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_campaigns() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_name + start_dt
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_name, start_dt
        FROM ods.campaigns
        GROUP BY campaign_name, start_dt
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в ods.campaigns по campaign_name + start_dt: % записей', v_duplicates;
    END IF;

    INSERT INTO dds.dim_campaigns (
        campaign_name,
        campaign_type,
        start_dt,
        end_dt,
        target_segment,
        card_product_id,
        reward_rate,
        budget,
        currency_id,
        owner_employee_id,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.campaign_name,
        o.campaign_type,
        o.start_dt,
        o.end_dt,
        o.target_segment,
        dcp.card_product_id,
        o.reward_rate,
        o.budget,
        dcur.currency_id,
        -- TODO: добавить JOIN на dds.dict_employees по нужному полю
        NULL AS owner_employee_id,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.campaigns o
    LEFT JOIN ods.dict_card_products ocp
           ON ocp.card_product_id = o.card_product_id
    LEFT JOIN dds.dict_card_products dcp
           ON TRIM(dcp.product_code) = TRIM(ocp.product_code)
    LEFT JOIN ods.dict_currencies ocur
           ON ocur.currency_id = o.currency_id
    LEFT JOIN dds.dict_currencies dcur
           ON UPPER(TRIM(dcur.currency_code)) = UPPER(TRIM(ocur.currency_code))
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dim_campaigns d
        WHERE LOWER(TRIM(d.campaign_name)) = LOWER(TRIM(o.campaign_name))
          AND d.start_dt = o.start_dt
    )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_campaigns() OWNER TO postgres;

--
-- TOC entry 344 (class 1255 OID 17309)
-- Name: load_dds_cards(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_cards() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей в ods по card_number_hash
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT card_number_hash
        FROM ods.cards
        GROUP BY card_number_hash
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в ods.cards по card_number_hash: % записей', v_duplicates;
    END IF;

    -- основная загрузка
    INSERT INTO dds.dim_cards (
        client_id,
        card_product_id,
        card_number_hash,
        card_status,
        open_dt,
        close_dt,
        expiry_dt,
        credit_limit,
        currency_id,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dc.client_id,
        dcp.card_product_id,
        o.card_number_hash,
        o.card_status,
        o.open_dt,
        o.close_dt,
        o.expiry_dt,
        o.credit_limit,
        dcur.currency_id,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.cards o
    -- резолвим client_id через ods → dds по full_name
    LEFT JOIN ods.clients oc
           ON oc.client_id = o.client_id
    LEFT JOIN dds.dim_clients dc
           ON LOWER(TRIM(dc.full_name)) = LOWER(TRIM(oc.full_name))
    -- резолвим card_product_id через product_code
    LEFT JOIN ods.dict_card_products ocp
           ON ocp.card_product_id = o.card_product_id
    LEFT JOIN dds.dict_card_products dcp
           ON TRIM(dcp.product_code) = TRIM(ocp.product_code)
    -- резолвим currency_id через currency_code
    LEFT JOIN ods.dict_currencies ocur
           ON ocur.currency_id = o.currency_id
    LEFT JOIN dds.dict_currencies dcur
           ON UPPER(TRIM(dcur.currency_code)) = UPPER(TRIM(ocur.currency_code))
    WHERE dc.client_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.dim_cards d
          WHERE d.card_number_hash = o.card_number_hash
      )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_cards() OWNER TO postgres;

--
-- TOC entry 338 (class 1255 OID 17307)
-- Name: load_dds_clients(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_clients() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dds.dim_clients (
        full_name,
        birth_dt,
        gender,
        city_id,
        segment,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.full_name,
        o.birth_dt,
        o.gender,
        d.city_id,
        o.segment,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.clients o
    LEFT JOIN ods.dict_cities oc
           ON oc.city_id = o.city_id
    LEFT JOIN dds.dict_cities d
           ON LOWER(TRIM(d.city_name)) = LOWER(TRIM(oc.city_name))
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dim_clients dc
        WHERE LOWER(TRIM(dc.full_name)) = LOWER(TRIM(o.full_name))
    )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_clients() OWNER TO postgres;

--
-- TOC entry 330 (class 1255 OID 17299)
-- Name: load_dds_dict_card_products(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_card_products() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dds.dict_card_products (
        product_code,
        product_name,
        product_category,
        product_tier,
        target_audience,
        min_age,
        max_age,
        annual_fee,
        cashback_base_rate,
        credit_limit_max,
        is_active,
        valid_from_dt,
        valid_to_dt,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.product_code,
        o.product_name,
        o.product_category,
        o.product_tier,
        o.target_audience,
        o.min_age,
        o.max_age,
        o.annual_fee,
        o.cashback_base_rate,
        o.credit_limit_max,
        o.is_active,
        o.valid_from_dt,
        o.valid_to_dt,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_card_products o
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dict_card_products d
        WHERE TRIM(d.product_code) = TRIM(o.product_code)
    )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_card_products() OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 17294)
-- Name: load_dds_dict_cities(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_cities() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dds.dict_cities (
        city_name,
        city_name_en,
        city_type,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.city_name,
        o.city_name_en,
        o.city_type,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_cities o
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dict_cities d
        WHERE LOWER(TRIM(d.city_name)) = LOWER(TRIM(o.city_name))
    )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_cities() OWNER TO postgres;

--
-- TOC entry 309 (class 1255 OID 17295)
-- Name: load_dds_dict_currencies(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_currencies() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dds.dict_currencies (
        currency_code,
        currency_name_ru,
        currency_symbol,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.currency_code,
        o.currency_name_ru,
        o.currency_symbol,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_currencies o
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dict_currencies d
        WHERE d.currency_code = o.currency_code
    )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_currencies() OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 17297)
-- Name: load_dds_dict_departments(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_departments() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- верхний уровень
    INSERT INTO dds.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        NULL,
        o.city_id,
        o.department_name,
        o.department_code,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_departments o
    WHERE o.parent_department_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.dict_departments d
          WHERE TRIM(d.department_code) = TRIM(o.department_code)
      )
    ON CONFLICT DO NOTHING;

    -- дочерние
    INSERT INTO dds.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dd_parent.department_id,
        o.city_id,
        o.department_name,
        o.department_code,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_departments o
    JOIN ods.dict_departments o_parent
      ON o_parent.department_id = o.parent_department_id
    JOIN dds.dict_departments dd_parent
      ON TRIM(dd_parent.department_code) = TRIM(o_parent.department_code)
    WHERE o.parent_department_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.dict_departments d
          WHERE TRIM(d.department_code) = TRIM(o.department_code)
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_departments() OWNER TO postgres;

--
-- TOC entry 329 (class 1255 OID 17298)
-- Name: load_dds_dict_employees(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_employees() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- без менеджера
    INSERT INTO dds.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dd.department_id,
        o.city_id,
        NULL,
        o.full_name,
        o.position,
        o.role,
        o.email,
        o.hire_dt,
        o.fire_dt,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_employees o
    LEFT JOIN dds.dict_departments dd
           ON dd.department_id = o.department_id
    WHERE o.manager_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.dict_employees d
          WHERE LOWER(TRIM(d.email)) = LOWER(TRIM(o.email))
      )
    ON CONFLICT DO NOTHING;

    -- с менеджером
    INSERT INTO dds.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dd.department_id,
        o.city_id,
        dm.employee_id,
        o.full_name,
        o.position,
        o.role,
        o.email,
        o.hire_dt,
        o.fire_dt,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_employees o
    LEFT JOIN dds.dict_departments dd
           ON dd.department_id = o.department_id
    LEFT JOIN ods.dict_employees o_manager
           ON o_manager.employee_id = o.manager_id
    LEFT JOIN dds.dict_employees dm
           ON LOWER(TRIM(dm.email)) = LOWER(TRIM(o_manager.email))
    WHERE o.manager_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.dict_employees d
          WHERE LOWER(TRIM(d.email)) = LOWER(TRIM(o.email))
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_employees() OWNER TO postgres;

--
-- TOC entry 310 (class 1255 OID 17296)
-- Name: load_dds_dict_mcc(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_dict_mcc() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dds.dict_mcc (
        mcc_code,
        mcc_name,
        mcc_group,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.mcc_code,
        o.mcc_name,
        o.mcc_group,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_mcc o
    WHERE NOT EXISTS (
        SELECT 1 FROM dds.dict_mcc d
        WHERE d.mcc_code = o.mcc_code
    )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_dds_dict_mcc() OWNER TO postgres;

--
-- TOC entry 346 (class 1255 OID 17408)
-- Name: load_dds_transactions(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_dds_transactions() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей в ods по card_id + transaction_dttm
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT card_id, transaction_dttm
        FROM ods.transactions
        GROUP BY card_id, transaction_dttm
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в ods.transactions по card_id + transaction_dttm: % записей', v_duplicates;
    END IF;

    -- основная загрузка
    INSERT INTO dds.fact_transactions (
        card_id,
        client_id,
        transaction_dttm,
        transaction_dt,
        amount,
        currency_id,
        mcc_id,
        merchant_name,
        city_id,
        transaction_type,
        status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        dc.card_id,
        dcl.client_id,
        o.transaction_dttm,
        o.transaction_dt,
        o.amount,
        dcur.currency_id,
        dm.mcc_id,
        o.merchant_name,
        dct.city_id,
        o.transaction_type,
        o.status,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.transactions o
    -- резолвим card_id через card_number_hash
    LEFT JOIN ods.cards oc
           ON oc.card_id = o.card_id
    LEFT JOIN dds.dim_cards dc
           ON dc.card_number_hash = oc.card_number_hash
    -- резолвим client_id
    LEFT JOIN ods.clients ocl
           ON ocl.client_id = o.client_id
    LEFT JOIN dds.dim_clients dcl
           ON LOWER(TRIM(dcl.full_name)) = LOWER(TRIM(ocl.full_name))
    -- резолвим currency_id
    LEFT JOIN ods.dict_currencies ocur
           ON ocur.currency_id = o.currency_id
    LEFT JOIN dds.dict_currencies dcur
           ON UPPER(TRIM(dcur.currency_code)) = UPPER(TRIM(ocur.currency_code))
    -- резолвим mcc_id через mcc_code
    LEFT JOIN ods.dict_mcc om
           ON om.mcc_code = o.mcc_code
    LEFT JOIN dds.dict_mcc dm
           ON dm.mcc_code = om.mcc_code
    -- резолвим city_id
    LEFT JOIN ods.dict_cities oct
           ON oct.city_id = o.city_id
    LEFT JOIN dds.dict_cities dct
           ON LOWER(TRIM(dct.city_name)) = LOWER(TRIM(oct.city_name))
    WHERE dc.card_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dds.fact_transactions f
          WHERE f.card_id          = dc.card_id
            AND f.transaction_dttm = o.transaction_dttm
      )
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION ods.load_dds_transactions() OWNER TO postgres;

--
-- TOC entry 336 (class 1255 OID 17305)
-- Name: load_md_dict_card_products(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_card_products() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO md.dict_card_products (
        product_code,
        product_name,
        product_category,
        product_tier,
        target_audience,
        min_age,
        max_age,
        annual_fee,
        cashback_base_rate,
        credit_limit_max,
        is_active,
        valid_from_dt,
        valid_to_dt,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.product_code,
        o.product_name,
        o.product_category,
        o.product_tier,
        o.target_audience,
        o.min_age,
        o.max_age,
        o.annual_fee,
        o.cashback_base_rate,
        o.credit_limit_max,
        o.is_active,
        o.valid_from_dt,
        o.valid_to_dt,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_card_products o
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_card_products m
          WHERE TRIM(m.product_code) = TRIM(o.product_code)
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_card_products() OWNER TO postgres;

--
-- TOC entry 331 (class 1255 OID 17300)
-- Name: load_md_dict_cities(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_cities() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO md.dict_cities (
        city_name,
        city_name_en,
        city_type,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.city_name,
        o.city_name_en,
        o.city_type,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_cities o
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_cities m
          WHERE LOWER(TRIM(m.city_name)) = LOWER(TRIM(o.city_name))
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_cities() OWNER TO postgres;

--
-- TOC entry 332 (class 1255 OID 17301)
-- Name: load_md_dict_currencies(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_currencies() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO md.dict_currencies (
        currency_code,
        currency_name_ru,
        currency_symbol,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.currency_code,
        o.currency_name_ru,
        o.currency_symbol,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_currencies o
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_currencies m
          WHERE m.currency_code = o.currency_code
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_currencies() OWNER TO postgres;

--
-- TOC entry 334 (class 1255 OID 17303)
-- Name: load_md_dict_departments(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_departments() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- верхний уровень
    INSERT INTO md.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        NULL,
        m_city.city_id,
        o.department_name,
        o.department_code,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_departments o
    LEFT JOIN md.dict_cities m_city
           ON LOWER(TRIM(m_city.city_name)) = LOWER(TRIM(
               (SELECT city_name FROM ods.dict_cities WHERE city_id = o.city_id)
           ))
    WHERE o.is_active          = TRUE
      AND o.is_deleted         = FALSE
      AND o.parent_department_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_departments m
          WHERE TRIM(m.department_code) = TRIM(o.department_code)
      )
    ON CONFLICT DO NOTHING;

    -- дочерние
    INSERT INTO md.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        md_parent.department_id,
        m_city.city_id,
        o.department_name,
        o.department_code,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_departments o
    JOIN ods.dict_departments o_parent
      ON o_parent.department_id = o.parent_department_id
    JOIN md.dict_departments md_parent
      ON TRIM(md_parent.department_code) = TRIM(o_parent.department_code)
    LEFT JOIN md.dict_cities m_city
           ON LOWER(TRIM(m_city.city_name)) = LOWER(TRIM(
               (SELECT city_name FROM ods.dict_cities WHERE city_id = o.city_id)
           ))
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND o.parent_department_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_departments m
          WHERE TRIM(m.department_code) = TRIM(o.department_code)
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_departments() OWNER TO postgres;

--
-- TOC entry 335 (class 1255 OID 17304)
-- Name: load_md_dict_employees(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_employees() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- без менеджера
    INSERT INTO md.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        md_dept.department_id,
        md_city.city_id,
        NULL,
        o.full_name,
        o.position,
        o.role,
        o.email,
        o.hire_dt,
        o.fire_dt,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_employees o
    LEFT JOIN ods.dict_departments o_dept
           ON o_dept.department_id = o.department_id
    LEFT JOIN md.dict_departments md_dept
           ON TRIM(md_dept.department_code) = TRIM(o_dept.department_code)
    LEFT JOIN ods.dict_cities o_city
           ON o_city.city_id = o.city_id
    LEFT JOIN md.dict_cities md_city
           ON LOWER(TRIM(md_city.city_name)) = LOWER(TRIM(o_city.city_name))
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND o.manager_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_employees m
          WHERE LOWER(TRIM(m.email)) = LOWER(TRIM(o.email))
      )
    ON CONFLICT DO NOTHING;

    -- с менеджером
    INSERT INTO md.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        md_dept.department_id,
        md_city.city_id,
        md_mgr.employee_id,
        o.full_name,
        o.position,
        o.role,
        o.email,
        o.hire_dt,
        o.fire_dt,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_employees o
    LEFT JOIN ods.dict_departments o_dept
           ON o_dept.department_id = o.department_id
    LEFT JOIN md.dict_departments md_dept
           ON TRIM(md_dept.department_code) = TRIM(o_dept.department_code)
    LEFT JOIN ods.dict_cities o_city
           ON o_city.city_id = o.city_id
    LEFT JOIN md.dict_cities md_city
           ON LOWER(TRIM(md_city.city_name)) = LOWER(TRIM(o_city.city_name))
    LEFT JOIN ods.dict_employees o_mgr
           ON o_mgr.employee_id = o.manager_id
    LEFT JOIN md.dict_employees md_mgr
           ON LOWER(TRIM(md_mgr.email)) = LOWER(TRIM(o_mgr.email))
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND o.manager_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_employees m
          WHERE LOWER(TRIM(m.email)) = LOWER(TRIM(o.email))
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_employees() OWNER TO postgres;

--
-- TOC entry 333 (class 1255 OID 17302)
-- Name: load_md_dict_mcc(); Type: FUNCTION; Schema: ods; Owner: postgres
--

CREATE FUNCTION ods.load_md_dict_mcc() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO md.dict_mcc (
        mcc_code,
        mcc_name,
        mcc_group,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        o.mcc_code,
        o.mcc_name,
        o.mcc_group,
        o.is_active,
        NOW(),
        NOW(),
        o.created_by,
        o.is_deleted
    FROM ods.dict_mcc o
    WHERE o.is_active  = TRUE
      AND o.is_deleted = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM md.dict_mcc m
          WHERE m.mcc_code = o.mcc_code
      )
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION ods.load_md_dict_mcc() OWNER TO postgres;

--
-- TOC entry 339 (class 1255 OID 17444)
-- Name: load_campaign_clients(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_campaign_clients() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_name + client_full_name + card_number_hash
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_name, client_full_name, card_number_hash
        FROM stg.campaign_clients
        WHERE is_processed = FALSE
        GROUP BY campaign_name, client_full_name, card_number_hash
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.campaign_clients по campaign_name + client_full_name + card_number_hash: % записей', v_duplicates;
    END IF;

    INSERT INTO ods.campaign_clients (
        campaign_id,
        client_id,
        card_id,
        enrollment_dttm,
        status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        c.campaign_id,
        oc.client_id,
        od.card_id,
        CASE WHEN TRIM(s.enrollment_dttm) ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
             THEN TRIM(s.enrollment_dttm)::TIMESTAMP ELSE NULL END,
        TRIM(s.status),
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.campaign_clients s
    -- находим campaign_id по campaign_name
    LEFT JOIN ods.campaigns c
           ON LOWER(TRIM(c.campaign_name)) = LOWER(TRIM(s.campaign_name))
    -- находим client_id по full_name
    LEFT JOIN ods.clients oc
           ON LOWER(TRIM(oc.full_name)) = LOWER(TRIM(s.client_full_name))
    -- находим card_id по card_number_hash
    LEFT JOIN ods.cards od
           ON od.card_number_hash = TRIM(s.card_number_hash)
    WHERE s.is_processed = FALSE
      AND c.campaign_id IS NOT NULL
      AND oc.client_id  IS NOT NULL
      AND od.card_id    IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.campaign_clients o
          WHERE o.campaign_id = c.campaign_id
            AND o.client_id   = oc.client_id
            AND o.card_id     = od.card_id
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.campaign_clients
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_campaign_clients() OWNER TO postgres;

--
-- TOC entry 340 (class 1255 OID 17445)
-- Name: load_campaign_rewards(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_campaign_rewards() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_name + client_full_name + transaction_dttm
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_name, client_full_name, transaction_dttm
        FROM stg.campaign_rewards
        WHERE is_processed = FALSE
        GROUP BY campaign_name, client_full_name, transaction_dttm
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.campaign_rewards по campaign_name + client_full_name + transaction_dttm: % записей', v_duplicates;
    END IF;

    INSERT INTO ods.campaign_rewards (
        campaign_id,
        client_id,
        transaction_id,
        reward_amount,
        reward_dt,
        reward_status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        c.campaign_id,
        oc.client_id,
        -- находим transaction_id по card_id + transaction_dttm
        ot.transaction_id,
        CASE WHEN TRIM(s.reward_amount) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.reward_amount)::NUMERIC(15,2) ELSE NULL END,
        CASE WHEN TRIM(s.reward_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.reward_dt)::DATE ELSE NULL END,
        TRIM(s.reward_status),
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.campaign_rewards s
    -- находим campaign_id по campaign_name
    LEFT JOIN ods.campaigns c
           ON LOWER(TRIM(c.campaign_name)) = LOWER(TRIM(s.campaign_name))
    -- находим client_id по full_name
    LEFT JOIN ods.clients oc
           ON LOWER(TRIM(oc.full_name)) = LOWER(TRIM(s.client_full_name))
    -- находим card_id по card_number_hash, затем transaction_id по card_id + transaction_dttm
    LEFT JOIN ods.cards od
           ON od.card_number_hash = TRIM(s.card_number_hash)
    LEFT JOIN ods.transactions ot
           ON ot.card_id          = od.card_id
          AND ot.transaction_dttm = TRIM(s.transaction_dttm)::TIMESTAMP
    WHERE s.is_processed = FALSE
      AND c.campaign_id    IS NOT NULL
      AND oc.client_id     IS NOT NULL
      AND ot.transaction_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.campaign_rewards o
          WHERE o.campaign_id    = c.campaign_id
            AND o.client_id      = oc.client_id
            AND o.transaction_id = ot.transaction_id
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.campaign_rewards
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_campaign_rewards() OWNER TO postgres;

--
-- TOC entry 337 (class 1255 OID 17443)
-- Name: load_campaigns(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_campaigns() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по campaign_name + start_dt
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT campaign_name, start_dt
        FROM stg.campaigns
        WHERE is_processed = FALSE
        GROUP BY campaign_name, start_dt
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.campaigns по campaign_name + start_dt: % записей', v_duplicates;
    END IF;

    INSERT INTO ods.campaigns (
        campaign_name,
        campaign_type,
        start_dt,
        end_dt,
        target_segment,
        card_product_id,
        reward_rate,
        budget,
        currency_id,
        owner_employee_id,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        TRIM(s.campaign_name),
        TRIM(s.campaign_type),
        CASE WHEN TRIM(s.start_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.start_dt)::DATE ELSE NULL END,
        CASE WHEN TRIM(s.end_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.end_dt)::DATE ELSE NULL END,
        TRIM(s.target_segment),
        cp.card_product_id,
        CASE WHEN TRIM(s.reward_rate) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.reward_rate)::NUMERIC(5,2) ELSE NULL END,
        CASE WHEN TRIM(s.budget) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.budget)::NUMERIC(15,2) ELSE NULL END,
        cur.currency_id,
        -- TODO: добавить JOIN на таблицу сотрудников по нужному полю (например email или full_name)
        -- LEFT JOIN ods.dict_employees e ON ... = ...
        NULL AS owner_employee_id,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.campaigns s
    LEFT JOIN ods.dict_card_products cp
           ON TRIM(cp.product_code) = TRIM(s.product_code)
    LEFT JOIN ods.dict_currencies cur
           ON UPPER(TRIM(cur.currency_code)) = UPPER(TRIM(s.currency_code))
    WHERE s.is_processed = FALSE
      AND s.campaign_name IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.campaigns o
          WHERE LOWER(TRIM(o.campaign_name)) = LOWER(TRIM(s.campaign_name))
            AND o.start_dt = TRIM(s.start_dt)::DATE
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.campaigns
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_campaigns() OWNER TO postgres;

--
-- TOC entry 343 (class 1255 OID 17308)
-- Name: load_cards(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_cards() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей внутри stg по card_number_hash
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT card_number_hash
        FROM stg.cards
        WHERE is_processed = FALSE
        GROUP BY card_number_hash
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.cards по card_number_hash: % записей', v_duplicates;
    END IF;

    -- проверка дублей по client_full_name + product_code
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT client_full_name, product_code
        FROM stg.cards
        WHERE is_processed = FALSE
        GROUP BY client_full_name, product_code
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.cards по client_full_name + product_code: % записей', v_duplicates;
    END IF;

    -- основная загрузка
    INSERT INTO ods.cards (
        client_id,
        card_product_id,
        card_number_hash,
        card_status,
        open_dt,
        close_dt,
        expiry_dt,
        credit_limit,
        currency_id,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        c.client_id,
        cp.card_product_id,
        TRIM(s.card_number_hash),
        TRIM(s.card_status),
        CASE WHEN s.open_dt IS NOT NULL AND TRIM(s.open_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.open_dt)::DATE ELSE NULL END,
        CASE WHEN s.close_dt IS NOT NULL AND TRIM(s.close_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.close_dt)::DATE ELSE NULL END,
        CASE WHEN s.expiry_dt IS NOT NULL AND TRIM(s.expiry_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.expiry_dt)::DATE ELSE NULL END,
        CASE WHEN s.credit_limit IS NOT NULL AND TRIM(s.credit_limit) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.credit_limit)::NUMERIC(15,2) ELSE NULL END,
        cur.currency_id,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.cards s
    LEFT JOIN ods.clients c
           ON LOWER(TRIM(c.full_name)) = LOWER(TRIM(s.client_full_name))
    LEFT JOIN ods.dict_card_products cp
           ON TRIM(cp.product_code) = TRIM(s.product_code)
    LEFT JOIN ods.dict_currencies cur
           ON UPPER(TRIM(cur.currency_code)) = UPPER(TRIM(s.currency_code))
    WHERE s.is_processed = FALSE
      AND s.card_number_hash IS NOT NULL
      AND c.client_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.cards o
          WHERE o.card_number_hash = TRIM(s.card_number_hash)
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.cards
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_cards() OWNER TO postgres;

--
-- TOC entry 342 (class 1255 OID 17306)
-- Name: load_clients(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_clients() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    INSERT INTO ods.clients (
        full_name,
        birth_dt,
        gender,
        city_id,
        segment,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        TRIM(s.full_name),
        CASE WHEN s.birth_dt IS NOT NULL AND TRIM(s.birth_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.birth_dt)::DATE ELSE NULL END,
        CASE WHEN UPPER(TRIM(s.gender)) IN ('M', 'F')
             THEN UPPER(TRIM(s.gender))::CHAR(1) ELSE NULL END,
        c.city_id,
        TRIM(s.segment),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.clients s
    LEFT JOIN ods.dict_cities c
           ON LOWER(TRIM(c.city_name)) = LOWER(TRIM(s.city_raw))
    WHERE s.is_processed = FALSE
      AND s.full_name IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.clients o
          WHERE LOWER(TRIM(o.full_name)) = LOWER(TRIM(s.full_name))
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.clients
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_clients() OWNER TO postgres;

--
-- TOC entry 324 (class 1255 OID 17291)
-- Name: load_dict_card_products(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_card_products() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    INSERT INTO ods.dict_card_products (
        product_code,
        product_name,
        product_category,
        product_tier,
        target_audience,
        min_age,
        max_age,
        annual_fee,
        cashback_base_rate,
        credit_limit_max,
        is_active,
        valid_from_dt,
        valid_to_dt,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        TRIM(s.product_code),
        TRIM(s.product_name),
        TRIM(s.product_category),
        TRIM(s.product_tier),
        TRIM(s.target_audience),
        CASE WHEN s.min_age IS NOT NULL AND TRIM(s.min_age) ~ '^\d+$'
             THEN TRIM(s.min_age)::SMALLINT ELSE NULL END,
        CASE WHEN s.max_age IS NOT NULL AND TRIM(s.max_age) ~ '^\d+$'
             THEN TRIM(s.max_age)::SMALLINT ELSE NULL END,
        CASE WHEN s.annual_fee IS NOT NULL AND TRIM(s.annual_fee) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.annual_fee)::NUMERIC(10,2) ELSE 0 END,
        CASE WHEN s.cashback_base_rate IS NOT NULL AND TRIM(s.cashback_base_rate) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.cashback_base_rate)::NUMERIC(5,2) ELSE 0 END,
        CASE WHEN s.credit_limit_max IS NOT NULL AND TRIM(s.credit_limit_max) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.credit_limit_max)::NUMERIC(15,2) ELSE NULL END,
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        CASE WHEN s.valid_from_dt IS NOT NULL AND TRIM(s.valid_from_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.valid_from_dt)::DATE ELSE NULL END,
        CASE WHEN s.valid_to_dt IS NOT NULL AND TRIM(s.valid_to_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.valid_to_dt)::DATE ELSE NULL END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_card_products s
    WHERE s.is_processed = FALSE
      AND s.product_code IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_card_products o
          WHERE TRIM(o.product_code) = TRIM(s.product_code)
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_card_products
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_dict_card_products() OWNER TO postgres;

--
-- TOC entry 308 (class 1255 OID 17288)
-- Name: load_dict_cities(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_cities() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ods.dict_cities (
        city_name,
        city_name_en,
        city_type,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        TRIM(s.city_name),
        TRIM(s.city_name_en),
        TRIM(s.city_type),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_cities s
    WHERE s.is_processed = FALSE
      AND s.city_name IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_cities o
          WHERE LOWER(TRIM(o.city_name)) = LOWER(TRIM(s.city_name))
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_cities
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$$;


ALTER FUNCTION stg.load_dict_cities() OWNER TO postgres;

--
-- TOC entry 311 (class 1255 OID 17289)
-- Name: load_dict_currencies(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_currencies() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ods.dict_currencies (
        currency_code,
        currency_name_ru,
        currency_symbol,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        UPPER(TRIM(s.currency_code)),
        TRIM(s.currency_name_ru),
        TRIM(s.currency_symbol),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_currencies s
    WHERE s.is_processed = FALSE
      AND s.currency_code IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_currencies o
          WHERE UPPER(TRIM(o.currency_code)) = UPPER(TRIM(s.currency_code))
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_currencies
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$$;


ALTER FUNCTION stg.load_dict_currencies() OWNER TO postgres;

--
-- TOC entry 325 (class 1255 OID 17292)
-- Name: load_dict_departments(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_departments() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- сначала грузим департаменты верхнего уровня (без родителя)
    INSERT INTO ods.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        NULL,
        c.city_id,
        TRIM(s.department_name),
        TRIM(s.department_code),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_departments s
    LEFT JOIN ods.dict_cities c
           ON LOWER(TRIM(c.city_name)) = LOWER(TRIM(s.src_city_name))
    WHERE s.is_processed = FALSE
      AND s.src_parent_dept_id IS NULL
      AND s.department_code IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_departments o
          WHERE TRIM(o.department_code) = TRIM(s.department_code)
      )
    ON CONFLICT DO NOTHING;

    -- затем грузим дочерние департаменты
    INSERT INTO ods.dict_departments (
        parent_department_id,
        city_id,
        department_name,
        department_code,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        p.department_id,
        c.city_id,
        TRIM(s.department_name),
        TRIM(s.department_code),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_departments s
    LEFT JOIN ods.dict_cities c
           ON LOWER(TRIM(c.city_name)) = LOWER(TRIM(s.src_city_name))
    LEFT JOIN stg.dict_departments sp
           ON sp.src_department_id = s.src_parent_dept_id
    LEFT JOIN ods.dict_departments p
           ON TRIM(p.department_code) = TRIM(sp.department_code)
    WHERE s.is_processed = FALSE
      AND s.src_parent_dept_id IS NOT NULL
      AND s.department_code IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_departments o
          WHERE TRIM(o.department_code) = TRIM(s.department_code)
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_departments
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$$;


ALTER FUNCTION stg.load_dict_departments() OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 17293)
-- Name: load_dict_employees(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_employees() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- сначала грузим сотрудников без менеджера
    INSERT INTO ods.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        d.department_id,
        c.city_id,
        NULL,
        TRIM(s.full_name),
        TRIM(s.position),
        TRIM(s.role),
        LOWER(TRIM(s.email)),
        CASE WHEN s.hire_dt IS NOT NULL AND TRIM(s.hire_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.hire_dt)::DATE ELSE NULL END,
        CASE WHEN s.fire_dt IS NOT NULL AND TRIM(s.fire_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.fire_dt)::DATE ELSE NULL END,
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_employees s
    LEFT JOIN ods.dict_departments d
           ON TRIM(d.department_code) = (
               SELECT TRIM(sd.department_code)
               FROM stg.dict_departments sd
               WHERE sd.src_department_id = s.src_department_id
               LIMIT 1
           )
    LEFT JOIN ods.dict_cities c
           ON LOWER(TRIM(c.city_name)) = LOWER(TRIM(s.src_city_name))
    WHERE s.is_processed = FALSE
      AND s.src_manager_id IS NULL
      AND s.email IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_employees o
          WHERE LOWER(TRIM(o.email)) = LOWER(TRIM(s.email))
      )
    ON CONFLICT DO NOTHING;

    -- затем грузим сотрудников с менеджером
    INSERT INTO ods.dict_employees (
        department_id,
        city_id,
        manager_id,
        full_name,
        position,
        role,
        email,
        hire_dt,
        fire_dt,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        d.department_id,
        c.city_id,
        m.employee_id,
        TRIM(s.full_name),
        TRIM(s.position),
        TRIM(s.role),
        LOWER(TRIM(s.email)),
        CASE WHEN s.hire_dt IS NOT NULL AND TRIM(s.hire_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.hire_dt)::DATE ELSE NULL END,
        CASE WHEN s.fire_dt IS NOT NULL AND TRIM(s.fire_dt) ~ '^\d{4}-\d{2}-\d{2}$'
             THEN TRIM(s.fire_dt)::DATE ELSE NULL END,
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_employees s
    LEFT JOIN ods.dict_departments d
           ON TRIM(d.department_code) = (
               SELECT TRIM(sd.department_code)
               FROM stg.dict_departments sd
               WHERE sd.src_department_id = s.src_department_id
               LIMIT 1
           )
    LEFT JOIN ods.dict_cities c
           ON LOWER(TRIM(c.city_name)) = LOWER(TRIM(s.src_city_name))
    LEFT JOIN stg.dict_employees sm
           ON sm.src_manager_id IS NULL
          AND sm.email = (
              SELECT sm2.email FROM stg.dict_employees sm2
              WHERE sm2.src_department_id = s.src_manager_id
              LIMIT 1
          )
    LEFT JOIN ods.dict_employees m
           ON LOWER(TRIM(m.email)) = LOWER(TRIM(sm.email))
    WHERE s.is_processed = FALSE
      AND s.src_manager_id IS NOT NULL
      AND s.email IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_employees o
          WHERE LOWER(TRIM(o.email)) = LOWER(TRIM(s.email))
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_employees
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_dict_employees() OWNER TO postgres;

--
-- TOC entry 323 (class 1255 OID 17290)
-- Name: load_dict_mcc(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_dict_mcc() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    INSERT INTO ods.dict_mcc (
        mcc_code,
        mcc_name,
        mcc_group,
        is_active,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        TRIM(s.mcc_code)::INT,
        TRIM(s.mcc_name),
        TRIM(s.mcc_group),
        CASE WHEN LOWER(TRIM(s.is_active)) = 'true' THEN TRUE ELSE FALSE END,
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.dict_mcc s
    WHERE s.is_processed = FALSE
      AND s.mcc_code IS NOT NULL
      AND TRIM(s.mcc_code) ~ '^\d+$'
      AND NOT EXISTS (
          SELECT 1 FROM ods.dict_mcc o
          WHERE o.mcc_code = TRIM(s.mcc_code)::INT
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.dict_mcc
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_dict_mcc() OWNER TO postgres;

--
-- TOC entry 345 (class 1255 OID 17407)
-- Name: load_transactions(); Type: FUNCTION; Schema: stg; Owner: postgres
--

CREATE FUNCTION stg.load_transactions() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_duplicates INT;
BEGIN
    -- проверка дублей по card_number_hash + transaction_dttm
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT card_number_hash, transaction_dttm
        FROM stg.transactions
        WHERE is_processed = FALSE
        GROUP BY card_number_hash, transaction_dttm
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates > 0 THEN
        RAISE EXCEPTION 'Найдены дубли в stg.transactions по card_number_hash + transaction_dttm: % записей', v_duplicates;
    END IF;

    -- основная загрузка
    INSERT INTO ods.transactions (
        card_id,
        client_id,
        transaction_dttm,
        transaction_dt,
        amount,
        currency_id,
        mcc_code,
        merchant_name,
        city_id,
        transaction_type,
        status,
        created_dttm,
        updated_dttm,
        created_by,
        is_deleted
    )
    SELECT
        oc.card_id,
        oc.client_id,
        CASE WHEN TRIM(s.transaction_dttm) ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
             THEN TRIM(s.transaction_dttm)::TIMESTAMP ELSE NULL end as transaction_dttm,
        CASE WHEN TRIM(s.transaction_dttm) ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
             THEN TRIM(s.transaction_dttm)::TIMESTAMP::DATE ELSE NULL end as transaction_dt,
        CASE WHEN TRIM(s.amount) ~ '^\d+(\.\d+)?$'
             THEN TRIM(s.amount)::NUMERIC(15,2) ELSE NULL end amount,
        cur.currency_id,
        dm.mcc_code as mcc_code,
        TRIM(s.merchant_name),
        ct.city_id,
        TRIM(s.transaction_type),
        TRIM(s.status),
        NOW(),
        NOW(),
        s.created_by,
        FALSE
    FROM stg.transactions s
    LEFT JOIN ods.cards oc
           ON oc.card_number_hash = TRIM(s.card_number_hash)
    LEFT JOIN ods.dict_currencies cur
           ON UPPER(TRIM(cur.currency_code)) = UPPER(TRIM(s.currency_code))
    LEFT JOIN ods.dict_cities ct
           ON LOWER(TRIM(ct.city_name)) = LOWER(TRIM(s.city_raw))
     left join  ods.dict_mcc dm on  s.mcc_code::int4 = dm.mcc_code::int4
    WHERE s.is_processed = FALSE
      AND s.card_number_hash IS NOT NULL
      AND oc.card_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ods.transactions o
          WHERE o.card_id           = oc.card_id
            AND o.transaction_dttm  = TRIM(s.transaction_dttm)::TIMESTAMP
      )
    ON CONFLICT DO NOTHING;

    UPDATE stg.transactions
    SET is_processed = TRUE
    WHERE is_processed = FALSE;

END;
$_$;


ALTER FUNCTION stg.load_transactions() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 288 (class 1259 OID 17049)
-- Name: dict_card_products; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_card_products (
    card_product_id bigint NOT NULL,
    product_code character varying(50) NOT NULL,
    product_name character varying(150) NOT NULL,
    product_category character varying(50),
    product_tier character varying(50),
    target_audience character varying(100),
    min_age smallint,
    max_age smallint,
    annual_fee numeric(10,2) DEFAULT 0 NOT NULL,
    cashback_base_rate numeric(5,2) DEFAULT 0 NOT NULL,
    credit_limit_max numeric(15,2),
    is_active boolean DEFAULT true NOT NULL,
    valid_from_dt date,
    valid_to_dt date,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_card_products OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 17048)
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_card_products_card_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_card_products_card_product_id_seq OWNER TO postgres;

--
-- TOC entry 5596 (class 0 OID 0)
-- Dependencies: 287
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_card_products_card_product_id_seq OWNED BY dds.dict_card_products.card_product_id;


--
-- TOC entry 278 (class 1259 OID 16958)
-- Name: dict_cities; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_cities (
    city_id bigint NOT NULL,
    city_name character varying(150) NOT NULL,
    city_name_en character varying(150),
    city_type character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_cities OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 16957)
-- Name: dict_cities_city_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_cities_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_cities_city_id_seq OWNER TO postgres;

--
-- TOC entry 5597 (class 0 OID 0)
-- Dependencies: 277
-- Name: dict_cities_city_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_cities_city_id_seq OWNED BY dds.dict_cities.city_id;


--
-- TOC entry 280 (class 1259 OID 16969)
-- Name: dict_currencies; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_currencies (
    currency_id bigint NOT NULL,
    currency_code character varying(10) NOT NULL,
    currency_name_ru character varying(100),
    currency_symbol character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_currencies OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 16968)
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_currencies_currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_currencies_currency_id_seq OWNER TO postgres;

--
-- TOC entry 5598 (class 0 OID 0)
-- Dependencies: 279
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_currencies_currency_id_seq OWNED BY dds.dict_currencies.currency_id;


--
-- TOC entry 284 (class 1259 OID 16995)
-- Name: dict_departments; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_departments (
    department_id bigint NOT NULL,
    parent_department_id bigint,
    city_id bigint,
    department_name character varying(150) NOT NULL,
    department_code character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_departments OWNER TO postgres;

--
-- TOC entry 283 (class 1259 OID 16994)
-- Name: dict_departments_department_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_departments_department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_departments_department_id_seq OWNER TO postgres;

--
-- TOC entry 5599 (class 0 OID 0)
-- Dependencies: 283
-- Name: dict_departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_departments_department_id_seq OWNED BY dds.dict_departments.department_id;


--
-- TOC entry 286 (class 1259 OID 17019)
-- Name: dict_employees; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_employees (
    employee_id bigint NOT NULL,
    department_id bigint,
    city_id bigint,
    manager_id bigint,
    full_name character varying(255) NOT NULL,
    "position" character varying(150),
    role character varying(50),
    email character varying(150) NOT NULL,
    hire_dt date,
    fire_dt date,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_employees OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 17018)
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_employees_employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_employees_employee_id_seq OWNER TO postgres;

--
-- TOC entry 5600 (class 0 OID 0)
-- Dependencies: 285
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_employees_employee_id_seq OWNED BY dds.dict_employees.employee_id;


--
-- TOC entry 282 (class 1259 OID 16982)
-- Name: dict_mcc; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dict_mcc (
    mcc_id bigint NOT NULL,
    mcc_code integer NOT NULL,
    mcc_name character varying(200) NOT NULL,
    mcc_group character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dict_mcc OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 16981)
-- Name: dict_mcc_mcc_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dict_mcc_mcc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dict_mcc_mcc_id_seq OWNER TO postgres;

--
-- TOC entry 5601 (class 0 OID 0)
-- Dependencies: 281
-- Name: dict_mcc_mcc_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dict_mcc_mcc_id_seq OWNED BY dds.dict_mcc.mcc_id;


--
-- TOC entry 294 (class 1259 OID 17108)
-- Name: dim_campaigns; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dim_campaigns (
    campaign_id bigint NOT NULL,
    campaign_name character varying(255) NOT NULL,
    campaign_type character varying(100) NOT NULL,
    start_dt date NOT NULL,
    end_dt date NOT NULL,
    target_segment character varying(50),
    card_product_id bigint,
    reward_rate numeric(5,2),
    budget numeric(15,2),
    currency_id bigint,
    owner_employee_id bigint,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dim_campaigns OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 17107)
-- Name: dim_campaigns_campaign_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dim_campaigns_campaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dim_campaigns_campaign_id_seq OWNER TO postgres;

--
-- TOC entry 5602 (class 0 OID 0)
-- Dependencies: 293
-- Name: dim_campaigns_campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dim_campaigns_campaign_id_seq OWNED BY dds.dim_campaigns.campaign_id;


--
-- TOC entry 292 (class 1259 OID 17082)
-- Name: dim_cards; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dim_cards (
    card_id bigint NOT NULL,
    client_id bigint NOT NULL,
    card_product_id bigint NOT NULL,
    card_number_hash character varying(64) NOT NULL,
    card_status character varying(50) NOT NULL,
    open_dt date NOT NULL,
    close_dt date,
    expiry_dt date,
    credit_limit numeric(15,2),
    currency_id bigint,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dim_cards OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 17081)
-- Name: dim_cards_card_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dim_cards_card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dim_cards_card_id_seq OWNER TO postgres;

--
-- TOC entry 5603 (class 0 OID 0)
-- Dependencies: 291
-- Name: dim_cards_card_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dim_cards_card_id_seq OWNED BY dds.dim_cards.card_id;


--
-- TOC entry 290 (class 1259 OID 17066)
-- Name: dim_clients; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.dim_clients (
    client_id bigint NOT NULL,
    full_name character varying(255) NOT NULL,
    birth_dt date,
    gender character(1),
    city_id bigint,
    segment character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.dim_clients OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 17065)
-- Name: dim_clients_client_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.dim_clients_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.dim_clients_client_id_seq OWNER TO postgres;

--
-- TOC entry 5604 (class 0 OID 0)
-- Dependencies: 289
-- Name: dim_clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.dim_clients_client_id_seq OWNED BY dds.dim_clients.client_id;


--
-- TOC entry 298 (class 1259 OID 17170)
-- Name: fact_campaign_clients; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.fact_campaign_clients (
    campaign_client_id bigint NOT NULL,
    campaign_id bigint NOT NULL,
    client_id bigint NOT NULL,
    card_id bigint NOT NULL,
    enrollment_dttm timestamp without time zone NOT NULL,
    status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.fact_campaign_clients OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 17169)
-- Name: fact_campaign_clients_campaign_client_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.fact_campaign_clients_campaign_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.fact_campaign_clients_campaign_client_id_seq OWNER TO postgres;

--
-- TOC entry 5605 (class 0 OID 0)
-- Dependencies: 297
-- Name: fact_campaign_clients_campaign_client_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.fact_campaign_clients_campaign_client_id_seq OWNED BY dds.fact_campaign_clients.campaign_client_id;


--
-- TOC entry 300 (class 1259 OID 17195)
-- Name: fact_campaign_rewards; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.fact_campaign_rewards (
    reward_id bigint NOT NULL,
    campaign_id bigint NOT NULL,
    client_id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    reward_amount numeric(15,2) NOT NULL,
    reward_dt date NOT NULL,
    reward_status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.fact_campaign_rewards OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 17194)
-- Name: fact_campaign_rewards_reward_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.fact_campaign_rewards_reward_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.fact_campaign_rewards_reward_id_seq OWNER TO postgres;

--
-- TOC entry 5606 (class 0 OID 0)
-- Dependencies: 299
-- Name: fact_campaign_rewards_reward_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.fact_campaign_rewards_reward_id_seq OWNED BY dds.fact_campaign_rewards.reward_id;


--
-- TOC entry 296 (class 1259 OID 17135)
-- Name: fact_transactions; Type: TABLE; Schema: dds; Owner: postgres
--

CREATE TABLE dds.fact_transactions (
    transaction_id bigint NOT NULL,
    card_id bigint NOT NULL,
    client_id bigint NOT NULL,
    transaction_dttm timestamp without time zone NOT NULL,
    transaction_dt date NOT NULL,
    amount numeric(15,2) NOT NULL,
    currency_id bigint,
    mcc_id bigint,
    merchant_name character varying(255),
    city_id bigint,
    transaction_type character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE dds.fact_transactions OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 17134)
-- Name: fact_transactions_transaction_id_seq; Type: SEQUENCE; Schema: dds; Owner: postgres
--

CREATE SEQUENCE dds.fact_transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dds.fact_transactions_transaction_id_seq OWNER TO postgres;

--
-- TOC entry 5607 (class 0 OID 0)
-- Dependencies: 295
-- Name: fact_transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: dds; Owner: postgres
--

ALTER SEQUENCE dds.fact_transactions_transaction_id_seq OWNED BY dds.fact_transactions.transaction_id;


--
-- TOC entry 233 (class 1259 OID 16481)
-- Name: dict_card_products; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_card_products (
    card_product_id integer NOT NULL,
    product_code character varying(50) NOT NULL,
    product_name character varying(150) NOT NULL,
    product_category character varying(50) NOT NULL,
    product_tier character varying(50),
    target_audience character varying(100),
    min_age smallint,
    max_age smallint,
    annual_fee numeric(10,2) DEFAULT 0 NOT NULL,
    cashback_base_rate numeric(5,2) DEFAULT 0 NOT NULL,
    credit_limit_max numeric(15,2),
    is_active boolean DEFAULT true NOT NULL,
    valid_from_dt date NOT NULL,
    valid_to_dt date,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_card_products OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16480)
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE; Schema: md; Owner: postgres
--

CREATE SEQUENCE md.dict_card_products_card_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE md.dict_card_products_card_product_id_seq OWNER TO postgres;

--
-- TOC entry 5608 (class 0 OID 0)
-- Dependencies: 232
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE OWNED BY; Schema: md; Owner: postgres
--

ALTER SEQUENCE md.dict_card_products_card_product_id_seq OWNED BY md.dict_card_products.card_product_id;


--
-- TOC entry 224 (class 1259 OID 16395)
-- Name: dict_cities; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_cities (
    city_id integer NOT NULL,
    city_name character varying(150) NOT NULL,
    city_name_en character varying(150),
    city_type character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_cities OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16394)
-- Name: dict_cities_city_id_seq; Type: SEQUENCE; Schema: md; Owner: postgres
--

CREATE SEQUENCE md.dict_cities_city_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE md.dict_cities_city_id_seq OWNER TO postgres;

--
-- TOC entry 5609 (class 0 OID 0)
-- Dependencies: 223
-- Name: dict_cities_city_id_seq; Type: SEQUENCE OWNED BY; Schema: md; Owner: postgres
--

ALTER SEQUENCE md.dict_cities_city_id_seq OWNED BY md.dict_cities.city_id;


--
-- TOC entry 226 (class 1259 OID 16406)
-- Name: dict_currencies; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_currencies (
    currency_id integer NOT NULL,
    currency_code character(3) NOT NULL,
    currency_name_ru character varying(100) NOT NULL,
    currency_symbol character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_currencies OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16405)
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE; Schema: md; Owner: postgres
--

CREATE SEQUENCE md.dict_currencies_currency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE md.dict_currencies_currency_id_seq OWNER TO postgres;

--
-- TOC entry 5610 (class 0 OID 0)
-- Dependencies: 225
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: md; Owner: postgres
--

ALTER SEQUENCE md.dict_currencies_currency_id_seq OWNED BY md.dict_currencies.currency_id;


--
-- TOC entry 229 (class 1259 OID 16428)
-- Name: dict_departments; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_departments (
    department_id integer NOT NULL,
    parent_department_id integer,
    city_id integer,
    department_name character varying(150) NOT NULL,
    department_code character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_departments OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16427)
-- Name: dict_departments_department_id_seq; Type: SEQUENCE; Schema: md; Owner: postgres
--

CREATE SEQUENCE md.dict_departments_department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE md.dict_departments_department_id_seq OWNER TO postgres;

--
-- TOC entry 5611 (class 0 OID 0)
-- Dependencies: 228
-- Name: dict_departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: md; Owner: postgres
--

ALTER SEQUENCE md.dict_departments_department_id_seq OWNED BY md.dict_departments.department_id;


--
-- TOC entry 231 (class 1259 OID 16451)
-- Name: dict_employees; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_employees (
    employee_id bigint NOT NULL,
    department_id integer,
    city_id integer,
    manager_id bigint,
    full_name character varying(255) NOT NULL,
    "position" character varying(150),
    role character varying(50),
    email character varying(150),
    hire_dt date NOT NULL,
    fire_dt date,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_employees OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16450)
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE; Schema: md; Owner: postgres
--

CREATE SEQUENCE md.dict_employees_employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE md.dict_employees_employee_id_seq OWNER TO postgres;

--
-- TOC entry 5612 (class 0 OID 0)
-- Dependencies: 230
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: md; Owner: postgres
--

ALTER SEQUENCE md.dict_employees_employee_id_seq OWNED BY md.dict_employees.employee_id;


--
-- TOC entry 227 (class 1259 OID 16418)
-- Name: dict_mcc; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.dict_mcc (
    mcc_code integer NOT NULL,
    mcc_name character varying(100) NOT NULL,
    mcc_group character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE md.dict_mcc OWNER TO postgres;

--
-- TOC entry 307 (class 1259 OID 24587)
-- Name: ltv; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.ltv (
    product_name character varying(50) NOT NULL,
    all_clients integer NOT NULL,
    sum_transaction numeric(15,2) NOT NULL,
    ltv numeric(15,2) NOT NULL,
    report_date date NOT NULL
);


ALTER TABLE md.ltv OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 17478)
-- Name: transaction_per_merchant; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.transaction_per_merchant (
    merchant_name character varying(50) NOT NULL,
    transaction_month date NOT NULL,
    transaction_sum numeric(15,2) NOT NULL,
    avg_check numeric(15,2) NOT NULL,
    unique_clients_count integer NOT NULL,
    city_id bigint
);


ALTER TABLE md.transaction_per_merchant OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 17465)
-- Name: transaction_sum; Type: TABLE; Schema: md; Owner: postgres
--

CREATE TABLE md.transaction_sum (
    product_code character varying(50) NOT NULL,
    count_card integer NOT NULL,
    transaction_dt date NOT NULL,
    transaction_sum numeric(15,2) NOT NULL
);


ALTER TABLE md.transaction_sum OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 16852)
-- Name: campaign_clients; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.campaign_clients (
    campaign_client_id bigint NOT NULL,
    campaign_id bigint NOT NULL,
    client_id bigint NOT NULL,
    card_id bigint NOT NULL,
    enrollment_dttm timestamp without time zone NOT NULL,
    status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.campaign_clients OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 16851)
-- Name: campaign_clients_campaign_client_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.campaign_clients_campaign_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.campaign_clients_campaign_client_id_seq OWNER TO postgres;

--
-- TOC entry 5613 (class 0 OID 0)
-- Dependencies: 273
-- Name: campaign_clients_campaign_client_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.campaign_clients_campaign_client_id_seq OWNED BY ods.campaign_clients.campaign_client_id;


--
-- TOC entry 276 (class 1259 OID 16877)
-- Name: campaign_rewards; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.campaign_rewards (
    reward_id bigint NOT NULL,
    campaign_id bigint NOT NULL,
    client_id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    reward_amount numeric(15,2) NOT NULL,
    reward_dt date NOT NULL,
    reward_status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.campaign_rewards OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 16876)
-- Name: campaign_rewards_reward_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.campaign_rewards_reward_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.campaign_rewards_reward_id_seq OWNER TO postgres;

--
-- TOC entry 5614 (class 0 OID 0)
-- Dependencies: 275
-- Name: campaign_rewards_reward_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.campaign_rewards_reward_id_seq OWNED BY ods.campaign_rewards.reward_id;


--
-- TOC entry 272 (class 1259 OID 16825)
-- Name: campaigns; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.campaigns (
    campaign_id bigint NOT NULL,
    campaign_name character varying(255) NOT NULL,
    campaign_type character varying(100) NOT NULL,
    start_dt date NOT NULL,
    end_dt date NOT NULL,
    target_segment character varying(50),
    card_product_id integer,
    reward_rate numeric(5,2),
    budget numeric(15,2),
    currency_id integer,
    owner_employee_id bigint,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.campaigns OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 16824)
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.campaigns_campaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.campaigns_campaign_id_seq OWNER TO postgres;

--
-- TOC entry 5615 (class 0 OID 0)
-- Dependencies: 271
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.campaigns_campaign_id_seq OWNED BY ods.campaigns.campaign_id;


--
-- TOC entry 268 (class 1259 OID 16765)
-- Name: cards; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.cards (
    card_id bigint NOT NULL,
    client_id bigint NOT NULL,
    card_product_id integer NOT NULL,
    card_number_hash character varying(64) NOT NULL,
    card_status character varying(50) NOT NULL,
    open_dt date NOT NULL,
    close_dt date,
    expiry_dt date,
    credit_limit numeric(15,2),
    currency_id integer,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.cards OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 16764)
-- Name: cards_card_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.cards_card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.cards_card_id_seq OWNER TO postgres;

--
-- TOC entry 5616 (class 0 OID 0)
-- Dependencies: 267
-- Name: cards_card_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.cards_card_id_seq OWNED BY ods.cards.card_id;


--
-- TOC entry 266 (class 1259 OID 16749)
-- Name: clients; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.clients (
    client_id bigint NOT NULL,
    full_name character varying(255) NOT NULL,
    birth_dt date,
    gender character(1),
    city_id integer,
    segment character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.clients OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 16748)
-- Name: clients_client_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.clients_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.clients_client_id_seq OWNER TO postgres;

--
-- TOC entry 5617 (class 0 OID 0)
-- Dependencies: 265
-- Name: clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.clients_client_id_seq OWNED BY ods.clients.client_id;


--
-- TOC entry 264 (class 1259 OID 16732)
-- Name: dict_card_products; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_card_products (
    card_product_id integer NOT NULL,
    product_code character varying(50) NOT NULL,
    product_name character varying(150) NOT NULL,
    product_category character varying(50) NOT NULL,
    product_tier character varying(50),
    target_audience character varying(100),
    min_age smallint,
    max_age smallint,
    annual_fee numeric(10,2) DEFAULT 0 NOT NULL,
    cashback_base_rate numeric(5,2) DEFAULT 0 NOT NULL,
    credit_limit_max numeric(15,2),
    is_active boolean DEFAULT true NOT NULL,
    valid_from_dt date NOT NULL,
    valid_to_dt date,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_card_products OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 16731)
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.dict_card_products_card_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.dict_card_products_card_product_id_seq OWNER TO postgres;

--
-- TOC entry 5618 (class 0 OID 0)
-- Dependencies: 263
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.dict_card_products_card_product_id_seq OWNED BY ods.dict_card_products.card_product_id;


--
-- TOC entry 255 (class 1259 OID 16646)
-- Name: dict_cities; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_cities (
    city_id integer NOT NULL,
    city_name character varying(150) NOT NULL,
    city_name_en character varying(150),
    city_type character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_cities OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 16645)
-- Name: dict_cities_city_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.dict_cities_city_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.dict_cities_city_id_seq OWNER TO postgres;

--
-- TOC entry 5619 (class 0 OID 0)
-- Dependencies: 254
-- Name: dict_cities_city_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.dict_cities_city_id_seq OWNED BY ods.dict_cities.city_id;


--
-- TOC entry 257 (class 1259 OID 16657)
-- Name: dict_currencies; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_currencies (
    currency_id integer NOT NULL,
    currency_code character(3) NOT NULL,
    currency_name_ru character varying(100) NOT NULL,
    currency_symbol character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_currencies OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 16656)
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.dict_currencies_currency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.dict_currencies_currency_id_seq OWNER TO postgres;

--
-- TOC entry 5620 (class 0 OID 0)
-- Dependencies: 256
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.dict_currencies_currency_id_seq OWNED BY ods.dict_currencies.currency_id;


--
-- TOC entry 260 (class 1259 OID 16679)
-- Name: dict_departments; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_departments (
    department_id integer NOT NULL,
    parent_department_id integer,
    city_id integer,
    department_name character varying(150) NOT NULL,
    department_code character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_departments OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 16678)
-- Name: dict_departments_department_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.dict_departments_department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.dict_departments_department_id_seq OWNER TO postgres;

--
-- TOC entry 5621 (class 0 OID 0)
-- Dependencies: 259
-- Name: dict_departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.dict_departments_department_id_seq OWNED BY ods.dict_departments.department_id;


--
-- TOC entry 262 (class 1259 OID 16702)
-- Name: dict_employees; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_employees (
    employee_id bigint NOT NULL,
    department_id integer,
    city_id integer,
    manager_id bigint,
    full_name character varying(255) NOT NULL,
    "position" character varying(150),
    role character varying(50),
    email character varying(150),
    hire_dt date NOT NULL,
    fire_dt date,
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_employees OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 16701)
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.dict_employees_employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.dict_employees_employee_id_seq OWNER TO postgres;

--
-- TOC entry 5622 (class 0 OID 0)
-- Dependencies: 261
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.dict_employees_employee_id_seq OWNED BY ods.dict_employees.employee_id;


--
-- TOC entry 258 (class 1259 OID 16669)
-- Name: dict_mcc; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.dict_mcc (
    mcc_code integer NOT NULL,
    mcc_name character varying(100) NOT NULL,
    mcc_group character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.dict_mcc OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 16790)
-- Name: transactions; Type: TABLE; Schema: ods; Owner: postgres
--

CREATE TABLE ods.transactions (
    transaction_id bigint NOT NULL,
    card_id bigint NOT NULL,
    client_id bigint NOT NULL,
    transaction_dttm timestamp without time zone NOT NULL,
    transaction_dt date NOT NULL,
    amount numeric(15,2) NOT NULL,
    currency_id integer,
    mcc_code integer,
    merchant_name character varying(255),
    city_id integer,
    transaction_type character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    updated_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE ods.transactions OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 16789)
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: ods; Owner: postgres
--

CREATE SEQUENCE ods.transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ods.transactions_transaction_id_seq OWNER TO postgres;

--
-- TOC entry 5623 (class 0 OID 0)
-- Dependencies: 269
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: ods; Owner: postgres
--

ALTER SEQUENCE ods.transactions_transaction_id_seq OWNED BY ods.transactions.transaction_id;


--
-- TOC entry 251 (class 1259 OID 16624)
-- Name: campaign_clients; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.campaign_clients (
    stg_id bigint NOT NULL,
    enrollment_dttm character varying(50),
    status character varying(50),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    campaign_name character varying(255),
    client_full_name character varying(255),
    card_number_hash character varying(64)
);


ALTER TABLE stg.campaign_clients OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 16623)
-- Name: campaign_clients_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.campaign_clients_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.campaign_clients_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5624 (class 0 OID 0)
-- Dependencies: 250
-- Name: campaign_clients_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.campaign_clients_stg_id_seq OWNED BY stg.campaign_clients.stg_id;


--
-- TOC entry 253 (class 1259 OID 16635)
-- Name: campaign_rewards; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.campaign_rewards (
    stg_id bigint NOT NULL,
    reward_amount character varying(50),
    reward_dt character varying(20),
    reward_status character varying(50),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    campaign_name character varying(255),
    client_full_name character varying(255),
    card_number_hash character varying(64),
    transaction_dttm character varying(50)
);


ALTER TABLE stg.campaign_rewards OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 16634)
-- Name: campaign_rewards_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.campaign_rewards_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.campaign_rewards_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5625 (class 0 OID 0)
-- Dependencies: 252
-- Name: campaign_rewards_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.campaign_rewards_stg_id_seq OWNED BY stg.campaign_rewards.stg_id;


--
-- TOC entry 249 (class 1259 OID 16611)
-- Name: campaigns; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.campaigns (
    stg_id bigint NOT NULL,
    campaign_name character varying(255),
    campaign_type character varying(100),
    start_dt character varying(20),
    end_dt character varying(20),
    target_segment character varying(50),
    product_code character varying(50),
    reward_rate character varying(50),
    budget character varying(50),
    currency_code character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.campaigns OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 16610)
-- Name: campaigns_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.campaigns_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.campaigns_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5626 (class 0 OID 0)
-- Dependencies: 248
-- Name: campaigns_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.campaigns_stg_id_seq OWNED BY stg.campaigns.stg_id;


--
-- TOC entry 302 (class 1259 OID 17276)
-- Name: cards; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.cards (
    stg_id bigint NOT NULL,
    client_full_name character varying(255) NOT NULL,
    product_code character varying(50) NOT NULL,
    card_number_hash character varying(64) NOT NULL,
    card_status character varying(50) NOT NULL,
    open_dt character varying(20),
    close_dt character varying(20),
    expiry_dt character varying(20),
    credit_limit character varying(20),
    currency_code character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.cards OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 17275)
-- Name: cards_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.cards_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.cards_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5627 (class 0 OID 0)
-- Dependencies: 301
-- Name: cards_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.cards_stg_id_seq OWNED BY stg.cards.stg_id;


--
-- TOC entry 247 (class 1259 OID 16572)
-- Name: clients; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.clients (
    stg_id bigint NOT NULL,
    full_name character varying(255),
    birth_dt character varying(20),
    gender character varying(10),
    city_raw character varying(150),
    segment character varying(50),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.clients OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 16571)
-- Name: clients_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.clients_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.clients_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5628 (class 0 OID 0)
-- Dependencies: 246
-- Name: clients_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.clients_stg_id_seq OWNED BY stg.clients.stg_id;


--
-- TOC entry 245 (class 1259 OID 16559)
-- Name: dict_card_products; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_card_products (
    stg_id bigint NOT NULL,
    product_code character varying(50),
    product_name character varying(150),
    product_category character varying(50),
    product_tier character varying(50),
    target_audience character varying(100),
    min_age character varying(10),
    max_age character varying(10),
    annual_fee character varying(50),
    cashback_base_rate character varying(50),
    credit_limit_max character varying(50),
    is_active character varying(10),
    valid_from_dt character varying(20),
    valid_to_dt character varying(20),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_card_products OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 16558)
-- Name: dict_card_products_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_card_products_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_card_products_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5629 (class 0 OID 0)
-- Dependencies: 244
-- Name: dict_card_products_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_card_products_stg_id_seq OWNED BY stg.dict_card_products.stg_id;


--
-- TOC entry 235 (class 1259 OID 16498)
-- Name: dict_cities; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_cities (
    stg_id bigint NOT NULL,
    city_name character varying(150),
    city_name_en character varying(150),
    city_type character varying(50),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_cities OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16497)
-- Name: dict_cities_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_cities_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_cities_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5630 (class 0 OID 0)
-- Dependencies: 234
-- Name: dict_cities_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_cities_stg_id_seq OWNED BY stg.dict_cities.stg_id;


--
-- TOC entry 237 (class 1259 OID 16511)
-- Name: dict_currencies; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_currencies (
    stg_id bigint NOT NULL,
    currency_code character varying(10),
    currency_name_ru character varying(100),
    currency_symbol character varying(10),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_currencies OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16510)
-- Name: dict_currencies_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_currencies_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_currencies_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5631 (class 0 OID 0)
-- Dependencies: 236
-- Name: dict_currencies_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_currencies_stg_id_seq OWNED BY stg.dict_currencies.stg_id;


--
-- TOC entry 241 (class 1259 OID 16533)
-- Name: dict_departments; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_departments (
    stg_id bigint NOT NULL,
    src_department_id character varying(50),
    src_parent_dept_id character varying(50),
    src_city_name character varying(150),
    department_name character varying(150),
    department_code character varying(50),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_departments OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16532)
-- Name: dict_departments_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_departments_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_departments_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5632 (class 0 OID 0)
-- Dependencies: 240
-- Name: dict_departments_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_departments_stg_id_seq OWNED BY stg.dict_departments.stg_id;


--
-- TOC entry 243 (class 1259 OID 16546)
-- Name: dict_employees; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_employees (
    stg_id bigint NOT NULL,
    src_department_id character varying(50),
    src_manager_id character varying(50),
    src_city_name character varying(150),
    full_name character varying(255),
    "position" character varying(150),
    role character varying(50),
    email character varying(150),
    hire_dt character varying(20),
    fire_dt character varying(20),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_employees OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 16545)
-- Name: dict_employees_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_employees_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_employees_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5633 (class 0 OID 0)
-- Dependencies: 242
-- Name: dict_employees_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_employees_stg_id_seq OWNED BY stg.dict_employees.stg_id;


--
-- TOC entry 239 (class 1259 OID 16522)
-- Name: dict_mcc; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.dict_mcc (
    stg_id bigint NOT NULL,
    mcc_code character varying(10),
    mcc_name character varying(100),
    mcc_group character varying(100),
    is_active character varying(10),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.dict_mcc OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16521)
-- Name: dict_mcc_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.dict_mcc_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.dict_mcc_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5634 (class 0 OID 0)
-- Dependencies: 238
-- Name: dict_mcc_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.dict_mcc_stg_id_seq OWNED BY stg.dict_mcc.stg_id;


--
-- TOC entry 304 (class 1259 OID 17395)
-- Name: transactions; Type: TABLE; Schema: stg; Owner: postgres
--

CREATE TABLE stg.transactions (
    stg_id bigint NOT NULL,
    card_number_hash character varying(64) NOT NULL,
    transaction_dttm character varying(50),
    amount character varying(50),
    currency_code character varying(10),
    mcc_code character varying(10),
    merchant_name character varying(255),
    city_raw character varying(150),
    transaction_type character varying(50),
    status character varying(50),
    load_dttm timestamp without time zone DEFAULT now() NOT NULL,
    src_name character varying(100) NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    created_dttm timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE stg.transactions OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 17394)
-- Name: transactions_stg_id_seq; Type: SEQUENCE; Schema: stg; Owner: postgres
--

CREATE SEQUENCE stg.transactions_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stg.transactions_stg_id_seq OWNER TO postgres;

--
-- TOC entry 5635 (class 0 OID 0)
-- Dependencies: 303
-- Name: transactions_stg_id_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: postgres
--

ALTER SEQUENCE stg.transactions_stg_id_seq OWNED BY stg.transactions.stg_id;


--
-- TOC entry 5155 (class 2604 OID 17052)
-- Name: dict_card_products card_product_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_card_products ALTER COLUMN card_product_id SET DEFAULT nextval('dds.dict_card_products_card_product_id_seq'::regclass);


--
-- TOC entry 5130 (class 2604 OID 16961)
-- Name: dict_cities city_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_cities ALTER COLUMN city_id SET DEFAULT nextval('dds.dict_cities_city_id_seq'::regclass);


--
-- TOC entry 5135 (class 2604 OID 16972)
-- Name: dict_currencies currency_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_currencies ALTER COLUMN currency_id SET DEFAULT nextval('dds.dict_currencies_currency_id_seq'::regclass);


--
-- TOC entry 5145 (class 2604 OID 16998)
-- Name: dict_departments department_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_departments ALTER COLUMN department_id SET DEFAULT nextval('dds.dict_departments_department_id_seq'::regclass);


--
-- TOC entry 5150 (class 2604 OID 17022)
-- Name: dict_employees employee_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees ALTER COLUMN employee_id SET DEFAULT nextval('dds.dict_employees_employee_id_seq'::regclass);


--
-- TOC entry 5140 (class 2604 OID 16985)
-- Name: dict_mcc mcc_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_mcc ALTER COLUMN mcc_id SET DEFAULT nextval('dds.dict_mcc_mcc_id_seq'::regclass);


--
-- TOC entry 5171 (class 2604 OID 17111)
-- Name: dim_campaigns campaign_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_campaigns ALTER COLUMN campaign_id SET DEFAULT nextval('dds.dim_campaigns_campaign_id_seq'::regclass);


--
-- TOC entry 5167 (class 2604 OID 17085)
-- Name: dim_cards card_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_cards ALTER COLUMN card_id SET DEFAULT nextval('dds.dim_cards_card_id_seq'::regclass);


--
-- TOC entry 5162 (class 2604 OID 17069)
-- Name: dim_clients client_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_clients ALTER COLUMN client_id SET DEFAULT nextval('dds.dim_clients_client_id_seq'::regclass);


--
-- TOC entry 5179 (class 2604 OID 17173)
-- Name: fact_campaign_clients campaign_client_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_clients ALTER COLUMN campaign_client_id SET DEFAULT nextval('dds.fact_campaign_clients_campaign_client_id_seq'::regclass);


--
-- TOC entry 5183 (class 2604 OID 17198)
-- Name: fact_campaign_rewards reward_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_rewards ALTER COLUMN reward_id SET DEFAULT nextval('dds.fact_campaign_rewards_reward_id_seq'::regclass);


--
-- TOC entry 5175 (class 2604 OID 17138)
-- Name: fact_transactions transaction_id; Type: DEFAULT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions ALTER COLUMN transaction_id SET DEFAULT nextval('dds.fact_transactions_transaction_id_seq'::regclass);


--
-- TOC entry 5017 (class 2604 OID 16484)
-- Name: dict_card_products card_product_id; Type: DEFAULT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_card_products ALTER COLUMN card_product_id SET DEFAULT nextval('md.dict_card_products_card_product_id_seq'::regclass);


--
-- TOC entry 4993 (class 2604 OID 16398)
-- Name: dict_cities city_id; Type: DEFAULT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_cities ALTER COLUMN city_id SET DEFAULT nextval('md.dict_cities_city_id_seq'::regclass);


--
-- TOC entry 4998 (class 2604 OID 16409)
-- Name: dict_currencies currency_id; Type: DEFAULT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_currencies ALTER COLUMN currency_id SET DEFAULT nextval('md.dict_currencies_currency_id_seq'::regclass);


--
-- TOC entry 5007 (class 2604 OID 16431)
-- Name: dict_departments department_id; Type: DEFAULT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_departments ALTER COLUMN department_id SET DEFAULT nextval('md.dict_departments_department_id_seq'::regclass);


--
-- TOC entry 5012 (class 2604 OID 16454)
-- Name: dict_employees employee_id; Type: DEFAULT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees ALTER COLUMN employee_id SET DEFAULT nextval('md.dict_employees_employee_id_seq'::regclass);


--
-- TOC entry 5122 (class 2604 OID 16855)
-- Name: campaign_clients campaign_client_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_clients ALTER COLUMN campaign_client_id SET DEFAULT nextval('ods.campaign_clients_campaign_client_id_seq'::regclass);


--
-- TOC entry 5126 (class 2604 OID 16880)
-- Name: campaign_rewards reward_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_rewards ALTER COLUMN reward_id SET DEFAULT nextval('ods.campaign_rewards_reward_id_seq'::regclass);


--
-- TOC entry 5118 (class 2604 OID 16828)
-- Name: campaigns campaign_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaigns ALTER COLUMN campaign_id SET DEFAULT nextval('ods.campaigns_campaign_id_seq'::regclass);


--
-- TOC entry 5110 (class 2604 OID 16768)
-- Name: cards card_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.cards ALTER COLUMN card_id SET DEFAULT nextval('ods.cards_card_id_seq'::regclass);


--
-- TOC entry 5105 (class 2604 OID 16752)
-- Name: clients client_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.clients ALTER COLUMN client_id SET DEFAULT nextval('ods.clients_client_id_seq'::regclass);


--
-- TOC entry 5098 (class 2604 OID 16735)
-- Name: dict_card_products card_product_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_card_products ALTER COLUMN card_product_id SET DEFAULT nextval('ods.dict_card_products_card_product_id_seq'::regclass);


--
-- TOC entry 5074 (class 2604 OID 16649)
-- Name: dict_cities city_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_cities ALTER COLUMN city_id SET DEFAULT nextval('ods.dict_cities_city_id_seq'::regclass);


--
-- TOC entry 5079 (class 2604 OID 16660)
-- Name: dict_currencies currency_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_currencies ALTER COLUMN currency_id SET DEFAULT nextval('ods.dict_currencies_currency_id_seq'::regclass);


--
-- TOC entry 5088 (class 2604 OID 16682)
-- Name: dict_departments department_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_departments ALTER COLUMN department_id SET DEFAULT nextval('ods.dict_departments_department_id_seq'::regclass);


--
-- TOC entry 5093 (class 2604 OID 16705)
-- Name: dict_employees employee_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees ALTER COLUMN employee_id SET DEFAULT nextval('ods.dict_employees_employee_id_seq'::regclass);


--
-- TOC entry 5114 (class 2604 OID 16793)
-- Name: transactions transaction_id; Type: DEFAULT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions ALTER COLUMN transaction_id SET DEFAULT nextval('ods.transactions_transaction_id_seq'::regclass);


--
-- TOC entry 5064 (class 2604 OID 16627)
-- Name: campaign_clients stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaign_clients ALTER COLUMN stg_id SET DEFAULT nextval('stg.campaign_clients_stg_id_seq'::regclass);


--
-- TOC entry 5069 (class 2604 OID 16638)
-- Name: campaign_rewards stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaign_rewards ALTER COLUMN stg_id SET DEFAULT nextval('stg.campaign_rewards_stg_id_seq'::regclass);


--
-- TOC entry 5059 (class 2604 OID 16614)
-- Name: campaigns stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaigns ALTER COLUMN stg_id SET DEFAULT nextval('stg.campaigns_stg_id_seq'::regclass);


--
-- TOC entry 5187 (class 2604 OID 17279)
-- Name: cards stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.cards ALTER COLUMN stg_id SET DEFAULT nextval('stg.cards_stg_id_seq'::regclass);


--
-- TOC entry 5054 (class 2604 OID 16575)
-- Name: clients stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.clients ALTER COLUMN stg_id SET DEFAULT nextval('stg.clients_stg_id_seq'::regclass);


--
-- TOC entry 5049 (class 2604 OID 16562)
-- Name: dict_card_products stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_card_products ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_card_products_stg_id_seq'::regclass);


--
-- TOC entry 5024 (class 2604 OID 16501)
-- Name: dict_cities stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_cities ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_cities_stg_id_seq'::regclass);


--
-- TOC entry 5029 (class 2604 OID 16514)
-- Name: dict_currencies stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_currencies ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_currencies_stg_id_seq'::regclass);


--
-- TOC entry 5039 (class 2604 OID 16536)
-- Name: dict_departments stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_departments ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_departments_stg_id_seq'::regclass);


--
-- TOC entry 5044 (class 2604 OID 16549)
-- Name: dict_employees stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_employees ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_employees_stg_id_seq'::regclass);


--
-- TOC entry 5034 (class 2604 OID 16525)
-- Name: dict_mcc stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_mcc ALTER COLUMN stg_id SET DEFAULT nextval('stg.dict_mcc_stg_id_seq'::regclass);


--
-- TOC entry 5192 (class 2604 OID 17398)
-- Name: transactions stg_id; Type: DEFAULT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.transactions ALTER COLUMN stg_id SET DEFAULT nextval('stg.transactions_stg_id_seq'::regclass);


--
-- TOC entry 5571 (class 0 OID 17049)
-- Dependencies: 288
-- Data for Name: dict_card_products; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_card_products (card_product_id, product_code, product_name, product_category, product_tier, target_audience, min_age, max_age, annual_fee, cashback_base_rate, credit_limit_max, is_active, valid_from_dt, valid_to_dt, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	MULTI_CARD	Мультикарта	debit	standard	Все клиенты	18	\N	0.00	2.00	\N	t	2021-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	DEBIT_STUDENT	Студенческая карта	debit	standard	Студенты 14–25 лет	14	25	0.00	2.00	\N	t	2018-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	DEBIT_SILVER	Серебряная карта	debit	silver	Массовый сегмент	18	\N	599.00	2.00	\N	t	2017-06-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	DEBIT_PREMIUM	Премиальная карта	debit	premium	VIP-клиенты	21	\N	15000.00	5.00	\N	t	2019-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	CREDIT_CLASSIC	Классическая кредитная	credit	standard	Масс-сегмент	21	\N	1200.00	1.00	100000.00	t	2015-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	DEBIT_SALARY	Зарплатная карта	debit	standard	Зарплатные клиенты	18	\N	0.00	1.50	\N	t	2015-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	CREDIT_GOLD	Золотая кредитная карта	credit	gold	Масс-сегмент	21	\N	3500.00	3.00	300000.00	t	2016-06-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	DEBIT_CHILD	Детская карта	debit	standard	Дети 6–14 лет	6	14	0.00	1.00	\N	t	2018-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	CREDIT_TRAVEL	Тревел-карта	credit	gold	Путешественники	21	\N	4900.00	3.00	500000.00	t	2020-03-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	CREDIT_PLATINUM	Платиновая кредитная карта	credit	platinum	Premium-сегмент	21	\N	10000.00	5.00	1000000.00	t	2018-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	DEBIT_GOLD	Золотая дебетовая карта	debit	gold	Массовый сегмент	18	\N	3000.00	3.00	\N	t	2016-01-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	PREPAID_VIRTUAL	Виртуальная предоплаченная	prepaid	standard	Онлайн-покупки	14	\N	0.00	0.00	\N	t	2022-06-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
13	CREDIT_CLASSIC_V1	Классическая кредитная (old)	credit	standard	Масс-сегмент (архив)	21	\N	900.00	0.50	50000.00	f	2010-01-01	2014-12-31	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
14	DEBIT_PENSIONER	Пенсионная карта	debit	standard	Пенсионеры от 55 лет	55	\N	0.00	3.00	\N	t	2019-09-01	\N	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5561 (class 0 OID 16958)
-- Dependencies: 278
-- Data for Name: dict_cities; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_cities (city_id, city_name, city_name_en, city_type, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Воронеж	Voronezh	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	Казань	Kazan	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	Новосибирск	Novosibirsk	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	Самара	Samara	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	Санкт-Петербург	Saint Petersburg	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	Пермь	Perm	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	Уфа	Ufa	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	Москва	Moscow	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	Ростов-на-Дону	Rostov-on-Don	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	Краснодар	Krasnodar	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	Екатеринбург	Yekaterinburg	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	Нижний Новгород	Nizhny Novgorod	city	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5563 (class 0 OID 16969)
-- Dependencies: 280
-- Data for Name: dict_currencies; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_currencies (currency_id, currency_code, currency_name_ru, currency_symbol, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	AMD	Армянский драм	֏	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	AED	Дирхам ОАЭ	د.إ	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	TRY	Турецкая лира	₺	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	EUR	Евро	€	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	CNY	Китайский юань	¥	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	CHF	Швейцарский франк	₣	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	KZT	Казахстанский тенге	₸	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	GBP	Британский фунт	£	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	RUB	Российский рубль	₽	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	USD	Доллар США	$	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	JPY	Японская иена	¥	f	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	BYN	Белорусский рубль	Br	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5567 (class 0 OID 16995)
-- Dependencies: 284
-- Data for Name: dict_departments; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_departments (department_id, parent_department_id, city_id, department_name, department_code, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	\N	8	Отдел карточных продуктов	CARDS	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	\N	8	Отдел разработки	DEV	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	\N	8	Отдел аналитики данных	ANALYTICS	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	\N	8	Головной офис	HQ	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	\N	8	Отдел CRM и акций	CRM	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	4	3	Филиал Новосибирск	BRANCH_NSK	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	4	5	Филиал Санкт-Петербург	BRANCH_SPB	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	4	8	Департамент информационных систем	IT	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	4	8	Департамент рисков	RISK	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	4	8	Департамент маркетинга	MARKETING	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	4	8	Департамент розничного бизнеса	RETAIL	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	4	11	Филиал Екатеринбург	BRANCH_EKB	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5569 (class 0 OID 17019)
-- Dependencies: 286
-- Data for Name: dict_employees; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_employees (employee_id, department_id, city_id, manager_id, full_name, "position", role, email, hire_dt, fire_dt, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	1	8	\N	Иванов Алексей Петрович	Председатель правления	admin	ivanov@bank.ru	2010-03-01	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	9	8	\N	Зайцева Мария Олеговна	Аналитик данных	analyst	zaitseva@bank.ru	2021-07-01	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	10	8	\N	Соколов Артём Владимирович	Разработчик БД	developer	sokolov@bank.ru	2020-03-15	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	11	8	\N	Федорова Анна Михайловна	Руководитель CRM	manager	fedorova@bank.ru	2018-11-05	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	12	8	\N	Морозов Игорь Николаевич	Руководитель отдела карт	manager	morozov@bank.ru	2017-04-20	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	9	8	\N	Волков Павел Игоревич	Старший аналитик данных	analyst	volkov@bank.ru	2019-02-14	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	8	3	1	Попов Сергей Алексеевич	Директор филиала НСК	manager	popov@bank.ru	2018-05-30	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	7	5	1	Лебедева Наталья Юрьевна	Директор филиала СПб	manager	lebedeva@bank.ru	2016-08-22	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	4	8	1	Козлов Дмитрий Сергеевич	Директор по маркетингу	manager	kozlov@bank.ru	2015-01-10	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	3	8	1	Смирнова Ольга Викторовна	Директор розничного бизнеса	manager	smirnova@bank.ru	2013-06-15	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	5	8	1	Кузнецова Ирина Борисовна	Директор по рискам	manager	kuznetsova@bank.ru	2012-10-17	2024-12-31	f	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	6	8	1	Новикова Екатерина Андреевна	ИТ-директор	admin	novikova@bank.ru	2014-09-01	\N	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5565 (class 0 OID 16982)
-- Dependencies: 282
-- Data for Name: dict_mcc; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dict_mcc (mcc_id, mcc_code, mcc_name, mcc_group, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	5411	Продуктовые магазины и супермаркеты	food	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
2	5912	Аптеки	health	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
3	5541	Автозаправочные станции	auto	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
4	4112	Железнодорожный транспорт	transport	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
5	5732	Электроника и бытовая техника	retail	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
6	7832	Кинотеатры	entertainment	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
7	5311	Универмаги	retail	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
8	7011	Гостиницы и отели	travel	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
9	4111	Городской транспорт	transport	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
10	5812	Рестораны и кафе	food	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
11	5999	Прочие магазины	other	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
12	3000	Авиабилеты	travel	t	2026-06-14 21:59:13.953734	2026-06-14 21:59:13.953734	etl_user	f
\.


--
-- TOC entry 5577 (class 0 OID 17108)
-- Dependencies: 294
-- Data for Name: dim_campaigns; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dim_campaigns (campaign_id, campaign_name, campaign_type, start_dt, end_dt, target_segment, card_product_id, reward_rate, budget, currency_id, owner_employee_id, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Бонусы для пенсионеров	bonus	2024-01-01	2024-12-31	pensioner	14	4.00	150000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	Бонусы за рестораны	bonus	2024-01-15	2024-04-15	premium	11	5.00	300000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	Платинум привилегии	cashback	2024-03-01	2024-06-30	vip	10	10.00	2000000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	Миль за путешествия	miles	2024-01-01	2024-06-30	premium	9	7.00	1000000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	Бонусы за электронику	bonus	2024-02-15	2024-04-30	premium	7	6.00	800000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	Кэшбэк на продукты	cashback	2024-01-01	2024-03-31	mass	6	3.00	500000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	Кэшбэк на одежду	cashback	2024-03-01	2024-05-31	mass	4	5.00	600000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	Кэшбэк на АЗС	cashback	2024-02-01	2024-05-31	mass	3	4.00	400000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	Кэшбэк для студентов	cashback	2024-01-01	2024-12-31	student	2	5.00	200000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	Кэшбэк мультикарта	cashback	2024-02-01	2024-07-31	mass	1	3.50	350000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5575 (class 0 OID 17082)
-- Dependencies: 292
-- Data for Name: dim_cards; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dim_cards (card_id, client_id, card_product_id, card_number_hash, card_status, open_dt, close_dt, expiry_dt, credit_limit, currency_id, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	22	14	c1262a319362dc7e46c2999968eb253a	active	2020-08-14	\N	2025-08-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	18	14	ad21653fb3d470a799eba9968537a34b	active	2021-12-28	\N	2026-12-28	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	26	11	46f11768f7cef80132f6ff8c6843a058	active	2020-07-31	\N	2025-07-31	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	13	11	1a655a3c9acf92ba96c3cbd01056a6e4	active	2021-03-08	\N	2026-03-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	38	11	455febaf1a66ab9ada96bbb04c66a325	active	2022-09-24	\N	2027-09-24	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	4	11	31ce0ae7081e61d01e17f4fbcd0382e0	active	2022-05-18	\N	2027-05-18	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	48	11	cc2739e03a55a2baf5079f4ab0f7b314	active	2022-04-08	\N	2027-04-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	19	10	08d29326c1e2fed2fd468254df8f1f52	active	2020-06-07	\N	2025-06-07	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	9	10	c2335bc3483ee04fa170be79301f1766	active	2020-04-21	\N	2025-04-21	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	46	10	8bd40b59e1a7bffb3a661ae5809f05c3	active	2019-05-27	\N	2024-05-27	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	44	9	853edf9fd145780210f8aeb2501495e0	active	2020-03-23	\N	2025-03-23	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	12	9	2c57c22c3172340709206b69b09af91e	active	2022-10-25	\N	2027-10-25	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
13	29	9	3ea95560ccca60e8538adc55f99a6edd	active	2021-06-04	\N	2026-06-04	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
14	15	7	74ba39b275456d6c87e5ad2ba7ba0d9c	active	2019-11-12	\N	2024-11-12	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
15	35	7	f0d7fb9fb2fe112c0321d9e53120ff94	active	2019-12-01	\N	2024-12-01	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
16	3	7	b7ffd93b27884ecb1026947e7514ed3d	active	2019-07-10	\N	2024-07-10	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
17	49	7	f2d81545d56b9a97be8cd346f2f069b3	active	2020-09-21	\N	2025-09-21	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
18	28	6	d9cb5930f320f334fa0691efc85e845f	active	2019-11-20	\N	2024-11-20	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
19	1	6	86463a6cac402bfda0d381168d46554f	active	2020-01-15	\N	2025-01-15	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
20	31	6	f26838f490873e4ffa6c10000f29372d	blocked	2018-01-27	\N	2023-01-27	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
21	41	6	2d6bbb7f244cbec701170225aa044d23	active	2019-07-08	\N	2024-07-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
22	47	6	b8976f5ac7c42d377f16f782bdf29377	blocked	2017-12-16	\N	2022-12-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
23	24	6	1b4dfbdd4d8bba68eec217b639d070ca	active	2022-10-06	\N	2027-10-06	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
24	11	6	051cd84fb9cc5d41b297f789c97179c8	active	2019-02-17	\N	2024-02-17	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
25	7	6	f2e35014b9478d853b50c8e599ccf1ac	active	2018-06-30	\N	2023-06-30	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
26	17	6	2e37bca84257c2f1bb6e2ec31ed3129e	blocked	2017-09-16	\N	2022-09-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
27	36	6	bd54775ae3dff3c32650a4d55ef687f7	active	2021-06-18	\N	2026-06-18	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
28	25	5	4db4802622eaf31ea48bfcbfeedb270c	active	2021-02-18	\N	2026-02-18	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
29	5	5	2cbf08d6d6c2b31b94d36cb7f3f29275	active	2020-09-27	\N	2025-09-27	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
30	37	5	6dc774b4932a7d7bb6d38f976f16ddbb	active	2020-02-07	\N	2025-02-07	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
31	23	4	c14c8ff146dc25cf2cff54334f7417a8	active	2019-03-29	\N	2024-03-29	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
32	6	4	a2e92e7ae62a8f49f3cfad77fd73e09e	active	2021-01-14	\N	2026-01-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
33	33	4	40556da66f53c530af922e2a5771740d	active	2020-08-22	\N	2025-08-22	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
34	42	4	4dbf0d5b7af1473e4510e2703ae8c7e5	active	2021-01-19	\N	2026-01-19	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
35	39	4	34f7afa3384d9e9362c7a1f81dba1d74	active	2021-04-12	\N	2026-04-12	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
36	50	4	dfe5c842ed015ea49d664ca6a33ac7d2	active	2021-02-14	\N	2026-02-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
37	14	4	1019ec9d35eccc7f727164f02827ae71	active	2020-07-19	\N	2025-07-19	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
38	21	3	2fb94a26ea921b25e3cfaf83a7d23f86	active	2021-05-11	\N	2026-05-11	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
39	10	3	13c76899fb85e6d585ac7dca0f1592e4	active	2021-08-05	\N	2026-08-05	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
40	2	3	b77db32220b56a5015adc16bcb974ff8	active	2021-03-22	\N	2026-03-22	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
41	34	3	ded0c48d679491231b7a90f78783a04b	active	2022-03-16	\N	2027-03-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
42	45	3	f6f59ab82bae5b8acaad2fe7489888a3	active	2021-10-14	\N	2026-10-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
43	30	3	44e09a74c39ed9d9b80f2bedd5181d32	active	2022-09-13	\N	2027-09-13	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
44	27	2	fe60d9deb07c243a2ebbe1c4f0eb8fa4	active	2022-04-15	\N	2027-04-15	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
45	43	2	4c381c194283ed3fdda088402a7d1e22	active	2022-08-30	\N	2027-08-30	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
46	20	2	1118c8a912757d2b1069a2ad974dfcce	active	2022-01-23	\N	2027-01-23	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
47	8	1	d17176b613a57a9f6cbb35bc1638b11f	active	2022-12-09	\N	2027-12-09	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
48	32	1	63a60d5282c045c2759f59f31b91ecf3	active	2021-05-09	\N	2026-05-09	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
49	16	1	cccab353dbd4c89f5025a47b2c182284	active	2022-04-03	\N	2027-04-03	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
50	40	1	d7071917a1bdad1dcc649d7c6f6171cb	active	2022-11-05	\N	2027-11-05	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5573 (class 0 OID 17066)
-- Dependencies: 290
-- Data for Name: dim_clients; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.dim_clients (client_id, full_name, birth_dt, gender, city_id, segment, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Зубова Анастасия Николаевна	1995-04-08	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	Гусева Людмила Аркадьевна	1960-06-18	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	Кузнецова Ирина Борисовна	1969-10-25	F	1	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	Никитина Галина Романовна	1989-10-06	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	Белова Тамара Ивановна	1958-12-28	F	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	Морозов Игорь Николаевич	1982-09-27	M	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	Кириллова Жанна Олеговна	1987-01-19	F	2	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	Воробьева Алина Константиновна	2000-09-13	F	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	Козлов Дмитрий Сергеевич	1978-11-03	M	3	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	Матвеева Полина Игоревна	1996-11-05	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	Фролова Оксана Владимировна	1973-11-20	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	Орлова Юлия Евгеньевна	1996-04-03	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
13	Тарасов Георгий Михайлович	1968-08-22	M	4	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
14	Тихонов Максим Юрьевич	1984-05-11	M	4	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
15	Назаров Олег Викторович	1983-10-14	M	4	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
16	Соколов Артём Владимирович	1975-04-21	M	4	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
17	Логинов Илья Станиславович	1998-04-15	M	5	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
18	Захаров Андрей Олегович	1979-11-12	M	5	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
19	Осипов Леонид Борисович	1981-04-12	M	5	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
20	Смирнова Ольга Викторовна	1990-07-22	F	5	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
21	Ильин Станислав Романович	1989-02-07	M	6	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
22	Борисов Евгений Анатольевич	1992-02-18	M	6	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
23	Герасимов Антон Леонидович	1970-09-21	M	6	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
24	Михайлов Роман Дмитриевич	1994-03-08	M	6	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
25	Калинин Руслан Дмитриевич	1986-12-16	M	7	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
26	Ефимов Константин Аркадьевич	1977-03-29	M	7	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
27	Попов Сергей Алексеевич	1983-02-17	M	7	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
28	Королёв Артур Васильевич	1985-12-01	M	7	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
29	Щербакова Вероника Павловна	1993-09-24	F	8	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
30	Петрова Светлана Александровна	1987-07-19	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
31	Иванов Алексей Петрович	1985-03-15	M	8	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
32	Соловьева Регина Аркадьевна	1988-02-14	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
33	Комарова Елена Дмитриевна	1980-07-31	F	8	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
34	Федорова Анна Михайловна	1993-01-14	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
35	Громова Надежда Петровна	1962-08-14	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
36	Медведева Татьяна Сергеевна	1991-05-27	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
37	Панова Кристина Евгеньевна	1997-03-16	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
38	Лебедева Наталья Юрьевна	1991-08-05	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
39	Сергеева Дарья Николаевна	1994-05-09	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
40	Зайцева Мария Олеговна	1997-12-09	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
41	Антонова Валерия Сергеевна	1999-01-23	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
42	Савельева Марина Юрьевна	1978-03-23	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
43	Новикова Екатерина Андреевна	1995-05-18	F	11	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
44	Куликов Денис Игоревич	1991-06-04	M	11	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
45	Степанов Виктор Павлович	1971-09-16	M	11	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
46	Громов Василий Петрович	1974-07-08	M	11	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
47	Макаров Владислав Олегович	1976-01-27	M	12	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
48	Волков Павел Игоревич	1988-06-30	M	12	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
49	Беляев Тимур Александрович	1999-08-30	M	12	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
50	Крылов Николай Федорович	1986-06-07	M	12	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5581 (class 0 OID 17170)
-- Dependencies: 298
-- Data for Name: fact_campaign_clients; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.fact_campaign_clients (campaign_client_id, campaign_id, client_id, card_id, enrollment_dttm, status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	10	39	48	2024-02-03 12:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	5	16	9	2024-02-16 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	10	40	47	2024-02-02 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	3	36	10	2024-03-03 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	3	50	8	2024-03-02 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	8	27	24	2024-02-03 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	9	17	44	2024-01-02 08:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	2	33	3	2024-01-17 10:15:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	7	12	49	2024-03-03 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	1	35	1	2024-01-03 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
11	5	24	4	2024-02-17 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
12	2	43	6	2024-01-16 09:30:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
13	9	49	45	2024-01-03 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
14	8	6	29	2024-02-02 08:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
15	6	31	19	2024-01-03 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
16	1	5	2	2024-01-02 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
17	4	3	12	2024-01-02 12:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
18	4	44	13	2024-01-03 13:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
19	7	34	32	2024-03-02 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
20	6	48	25	2024-01-04 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5583 (class 0 OID 17195)
-- Dependencies: 300
-- Data for Name: fact_campaign_rewards; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.fact_campaign_rewards (reward_id, campaign_id, client_id, transaction_id, reward_amount, reward_dt, reward_status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	7	34	29	750.00	2024-03-02	pending	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	6	48	22	21.00	2024-01-12	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	3	50	7	2800.00	2024-03-03	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	2	33	3	140.00	2024-01-31	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	7	12	45	49.00	2024-03-03	pending	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	1	35	1	44.00	2024-01-27	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	10	39	44	136.50	2024-02-07	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	5	24	4	53.40	2024-02-18	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	8	27	21	136.00	2024-01-16	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	8	6	26	84.00	2024-01-10	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
11	5	16	8	2700.00	2024-02-17	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
12	4	44	12	4690.00	2024-02-04	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
13	6	31	17	45.00	2024-01-06	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
14	2	43	6	22.50	2024-01-09	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
15	10	40	43	196.00	2024-02-03	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
16	9	17	40	21.50	2024-02-02	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
17	4	3	11	840.00	2024-01-17	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
18	1	5	2	22.00	2024-01-23	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
19	9	49	41	31.00	2024-02-18	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
20	3	36	9	1350.00	2024-03-04	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5579 (class 0 OID 17135)
-- Dependencies: 296
-- Data for Name: fact_transactions; Type: TABLE DATA; Schema: dds; Owner: postgres
--

COPY dds.fact_transactions (transaction_id, card_id, client_id, transaction_dttm, transaction_dt, amount, currency_id, mcc_id, merchant_name, city_id, transaction_type, status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
9	10	46	2024-02-20 08:05:00	2024-02-20	13500.00	9	\N	Massimo Dutti	9	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
10	11	44	2024-02-18 11:35:00	2024-02-18	89000.00	9	\N	S7 Airlines	10	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
11	12	12	2024-01-16 15:30:00	2024-01-16	12000.00	9	\N	Туттиairlines	1	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
12	13	29	2024-02-03 12:20:00	2024-02-03	67000.00	9	\N	Аэрофлот	11	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
14	15	35	2024-02-09 11:50:00	2024-02-09	7600.00	9	\N	Nike	7	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
15	16	3	2024-01-07 09:15:00	2024-01-07	8500.00	9	\N	Zara	3	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
25	28	25	2024-01-29 14:15:00	2024-01-29	9800.00	9	\N	Adidas	6	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
33	37	14	2024-01-18 17:20:00	2024-01-18	6700.00	9	\N	H&M	8	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
19	21	41	2024-02-15 14:20:00	2024-02-15	5800.00	9	10	Ginza	11	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
189	35	39	2024-01-13 13:30:00	2024-01-13	1800.00	9	10	KFC	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
1	1	22	2024-01-26 10:05:00	2024-01-26	1100.00	9	3	Газпромнефть	9	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
2	2	18	2024-01-22 16:00:00	2024-01-22	550.00	9	9	Автобус	2	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
3	3	26	2024-01-30 11:00:00	2024-01-30	2800.00	9	10	Якитория	8	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
4	4	13	2024-01-17 09:00:00	2024-01-17	890.00	9	11	Fix Price	6	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
5	5	38	2024-02-12 13:05:00	2024-02-12	22000.00	9	5	Apple Store	8	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
6	6	4	2024-01-08 14:30:00	2024-01-08	450.00	9	9	Метро	11	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
7	8	19	2024-01-23 19:25:00	2024-01-23	28000.00	9	5	М.Видео	12	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
8	9	9	2024-01-13 20:15:00	2024-01-13	45000.00	9	8	Marriott	4	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
13	14	15	2024-01-19 12:10:00	2024-01-19	2300.00	9	10	Шоколадница	5	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
16	18	28	2024-02-02 08:45:00	2024-02-02	5100.00	9	3	Роснефть	3	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
17	19	1	2024-01-05 10:23:00	2024-01-05	1500.00	9	1	Пятёрочка	8	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
18	20	31	2024-02-05 10:55:00	2024-02-05	780.00	9	2	Планета здоровья	12	purchase	declined	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
20	23	24	2024-01-28 09:30:00	2024-01-28	1650.00	9	11	Читай-город	1	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
21	24	11	2024-01-15 10:45:00	2024-01-15	3400.00	9	3	Лукойл	7	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
22	25	7	2024-01-11 16:45:00	2024-01-11	700.00	9	1	Магнит	12	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
23	26	17	2024-01-21 11:35:00	2024-01-21	1800.00	9	2	Ригла	11	purchase	declined	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
24	27	36	2024-02-10 16:35:00	2024-02-10	1900.00	9	1	Вкусвилл	1	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
26	29	5	2024-01-09 18:00:00	2024-01-09	2100.00	9	2	Аптека 36.6	2	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
27	30	37	2024-02-11 08:20:00	2024-02-11	4500.00	9	10	Макдоналдс	6	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
28	31	23	2024-01-27 15:55:00	2024-01-27	32000.00	9	8	Hilton	7	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
29	32	6	2024-01-10 11:20:00	2024-01-10	15000.00	9	5	DNS	8	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
30	33	33	2024-02-07 09:25:00	2024-02-07	18500.00	9	5	Эльдорадо	4	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
31	34	42	2024-02-16 09:05:00	2024-02-16	41000.00	9	8	Radisson	2	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
32	35	39	2024-02-13 17:50:00	2024-02-13	3100.00	9	3	BP	5	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
34	38	21	2024-01-25 13:40:00	2024-01-25	4200.00	9	10	KFC	4	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
35	39	10	2024-01-14 13:00:00	2024-01-14	1200.00	9	1	Лента	9	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
36	40	2	2024-01-06 12:45:00	2024-01-06	3200.00	9	10	Кофемания	5	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
37	41	34	2024-02-08 15:15:00	2024-02-08	2200.00	9	11	Sunlight	9	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
38	42	45	2024-02-19 16:20:00	2024-02-19	1750.00	9	11	Леруа Мерлен	4	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
39	43	30	2024-02-04 17:10:00	2024-02-04	1350.00	9	1	Перекрёсток	2	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
40	44	27	2024-02-01 16:30:00	2024-02-01	430.00	9	9	Трамвай	5	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
41	45	43	2024-02-17 15:50:00	2024-02-17	620.00	9	9	Метро	12	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
42	46	20	2024-01-24 08:15:00	2024-01-24	760.00	9	1	Дикси	10	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
43	47	8	2024-01-12 08:30:00	2024-01-12	5600.00	9	10	Burger King	10	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
44	48	32	2024-02-06 14:40:00	2024-02-06	3900.00	9	10	Теремок	10	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
45	49	16	2024-01-20 14:50:00	2024-01-20	980.00	9	1	Ашан	3	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
46	50	40	2024-02-14 10:35:00	2024-02-14	850.00	9	1	Красное&Белое	3	purchase	success	2026-06-16 18:29:07.392885	2026-06-16 18:29:07.392885	etl_user	f
47	19	1	2024-01-18 09:15:00	2024-01-18	3200.00	9	10	Кофемания	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
48	19	1	2024-01-25 14:40:00	2024-01-25	450.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
49	19	1	2024-02-03 11:20:00	2024-02-03	8700.00	9	5	DNS	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
50	19	1	2024-02-14 18:30:00	2024-02-14	2100.00	9	2	Аптека 36.6	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
51	19	1	2024-02-28 13:05:00	2024-02-28	980.00	9	1	Магнит	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
52	19	1	2024-03-07 09:50:00	2024-03-07	15000.00	9	7	ЦУМ	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
53	19	1	2024-03-15 16:25:00	2024-03-15	560.00	9	10	Шоколадница	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
54	19	1	2024-03-22 12:10:00	2024-03-22	1200.00	9	1	Вкусвилл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
55	19	1	2024-04-02 08:45:00	2024-04-02	450.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
56	19	1	2024-04-11 17:30:00	2024-04-11	4500.00	9	10	Якитория	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
57	19	1	2024-04-20 10:15:00	2024-04-20	780.00	9	2	Ригла	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
58	19	1	2024-05-05 14:00:00	2024-05-05	1650.00	9	1	Перекрёсток	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
59	19	1	2024-05-18 19:20:00	2024-05-18	350.00	9	6	Синема Парк	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
60	40	2	2024-01-19 10:30:00	2024-01-19	1100.00	9	1	Лента	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
61	40	2	2024-02-01 15:15:00	2024-02-01	2800.00	9	3	Лукойл	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
62	40	2	2024-02-12 09:40:00	2024-02-12	650.00	9	9	Автобус	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
63	40	2	2024-02-24 17:55:00	2024-02-24	12000.00	9	7	Галерея	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
64	40	2	2024-03-08 11:20:00	2024-03-08	890.00	9	2	Планета здоровья	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
65	40	2	2024-03-19 14:35:00	2024-03-19	4100.00	9	10	Burger King	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
66	40	2	2024-04-03 08:10:00	2024-04-03	1900.00	9	1	Пятёрочка	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
67	40	2	2024-04-15 16:45:00	2024-04-15	560.00	9	9	Трамвай	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
68	40	2	2024-04-28 12:20:00	2024-04-28	7600.00	9	5	М.Видео	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
69	40	2	2024-05-10 10:05:00	2024-05-10	2300.00	9	10	Теремок	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
70	40	2	2024-05-22 18:30:00	2024-05-22	450.00	9	6	Аврора	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
71	16	3	2024-01-21 14:50:00	2024-01-21	1200.00	9	1	Магнит	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
72	16	3	2024-02-05 11:25:00	2024-02-05	3400.00	9	3	Роснефть	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
73	16	3	2024-02-18 16:40:00	2024-02-18	780.00	9	2	Аптека 36.6	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
74	16	3	2024-03-02 09:05:00	2024-03-02	2600.00	9	10	KFC	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
75	16	3	2024-03-14 13:30:00	2024-03-14	450.00	9	9	Метро	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
76	16	3	2024-03-27 18:15:00	2024-03-27	11000.00	9	5	Эльдорадо	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
77	16	3	2024-04-08 10:50:00	2024-04-08	1500.00	9	1	Вкусвилл	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
78	16	3	2024-04-22 15:25:00	2024-04-22	4800.00	9	10	Гинза	3	purchase	declined	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
79	16	3	2024-05-06 09:00:00	2024-05-06	1800.00	9	11	Fix Price	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
80	16	3	2024-05-20 14:35:00	2024-05-20	650.00	9	2	Ригла	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
81	6	4	2024-01-22 10:15:00	2024-01-22	2300.00	9	10	Шоколадница	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
82	6	4	2024-02-04 16:50:00	2024-02-04	1100.00	9	1	Перекрёсток	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
83	6	4	2024-02-16 09:25:00	2024-02-16	4500.00	9	3	Газпромнефть	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
84	6	4	2024-02-27 14:00:00	2024-02-27	8900.00	9	7	Гринвич	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
85	6	4	2024-03-10 11:35:00	2024-03-10	560.00	9	2	Планета здоровья	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
86	6	4	2024-03-23 17:10:00	2024-03-23	3200.00	9	10	Якитория	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
87	6	4	2024-04-05 08:45:00	2024-04-05	1700.00	9	1	Лента	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
88	6	4	2024-04-18 15:20:00	2024-04-18	13000.00	9	5	DNS	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
89	6	4	2024-05-01 10:55:00	2024-05-01	450.00	9	9	Автобус	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
90	6	4	2024-05-14 16:30:00	2024-05-14	2800.00	9	10	Burger King	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
91	6	4	2024-05-27 12:05:00	2024-05-27	900.00	9	11	Читай-город	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
92	29	5	2024-01-23 11:35:00	2024-01-23	3400.00	9	3	Лукойл	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
93	29	5	2024-02-06 08:10:00	2024-02-06	1300.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
94	29	5	2024-02-19 14:45:00	2024-02-19	5600.00	9	10	Чайхона №1	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
95	29	5	2024-03-03 10:20:00	2024-03-03	450.00	9	9	Метро	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
96	29	5	2024-03-16 16:55:00	2024-03-16	9800.00	9	7	Мега	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
97	29	5	2024-03-29 12:30:00	2024-03-29	2700.00	9	3	Татнефть	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
98	29	5	2024-04-10 09:05:00	2024-04-10	1600.00	9	1	Магнит	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
99	29	5	2024-04-23 15:40:00	2024-04-23	4200.00	9	10	KFC	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
100	29	5	2024-05-07 11:15:00	2024-05-07	780.00	9	2	Ригла	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
101	29	5	2024-05-19 17:50:00	2024-05-19	6200.00	9	5	Samsung	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
102	29	5	2024-05-28 08:25:00	2024-05-28	1100.00	9	1	Вкусвилл	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
103	29	5	2024-06-05 14:00:00	2024-06-05	350.00	9	6	Синема Парк	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
104	32	6	2024-01-24 16:55:00	2024-01-24	2400.00	9	10	Якитория	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
105	32	6	2024-02-07 10:30:00	2024-02-07	1100.00	9	1	Перекрёсток	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
106	32	6	2024-02-20 15:05:00	2024-02-20	3800.00	9	3	Лукойл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
107	32	6	2024-03-05 09:40:00	2024-03-05	890.00	9	2	Аптека 36.6	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
108	32	6	2024-03-18 14:15:00	2024-03-18	450.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
109	32	6	2024-04-01 11:50:00	2024-04-01	7200.00	9	5	М.Видео	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
110	32	6	2024-04-14 17:25:00	2024-04-14	1900.00	9	1	Вкусвилл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
111	32	6	2024-05-02 09:00:00	2024-05-02	3100.00	9	10	Кофемания	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
112	32	6	2024-05-16 14:35:00	2024-05-16	1400.00	9	11	Читай-город	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
113	25	7	2024-01-25 12:20:00	2024-01-25	2900.00	9	10	Burger King	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
114	25	7	2024-02-08 08:55:00	2024-02-08	4200.00	9	3	Роснефть	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
115	25	7	2024-02-21 15:30:00	2024-02-21	650.00	9	9	Автобус	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
116	25	7	2024-03-06 11:05:00	2024-03-06	10500.00	9	7	Фантастика	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
117	25	7	2024-03-19 17:40:00	2024-03-19	1200.00	9	1	Пятёрочка	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
118	25	7	2024-04-02 09:15:00	2024-04-02	560.00	9	2	Ригла	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
119	25	7	2024-04-15 14:50:00	2024-04-15	8900.00	9	5	DNS	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
120	25	7	2024-05-01 10:25:00	2024-05-01	3400.00	9	10	KFC	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
121	25	7	2024-05-13 16:00:00	2024-05-13	1700.00	9	1	Лента	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
122	25	7	2024-05-26 11:35:00	2024-05-26	400.00	9	6	Киномакс	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
123	47	8	2024-01-26 14:05:00	2024-01-26	1300.00	9	1	Магнит	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
124	47	8	2024-02-09 10:40:00	2024-02-09	3600.00	9	3	Лукойл	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
125	47	8	2024-02-22 16:15:00	2024-02-22	780.00	9	2	Аптека 36.6	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
126	47	8	2024-03-07 09:50:00	2024-03-07	7400.00	9	7	Красная площадь	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
127	47	8	2024-03-20 15:25:00	2024-03-20	450.00	9	9	Автобус	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
128	47	8	2024-04-04 11:00:00	2024-04-04	2100.00	9	10	Чайхона №1	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
129	47	8	2024-04-17 17:35:00	2024-04-17	11000.00	9	5	Эльдорадо	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
130	47	8	2024-05-03 09:10:00	2024-05-03	1600.00	9	1	Перекрёсток	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
131	47	8	2024-05-17 14:45:00	2024-05-17	2800.00	9	10	Якитория	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
132	9	9	2024-01-15 09:30:00	2024-01-15	38000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
133	9	9	2024-01-28 14:00:00	2024-01-28	42000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
134	9	9	2024-02-10 11:45:00	2024-02-10	51000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
135	9	9	2024-02-23 16:20:00	2024-02-23	39000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
136	9	9	2024-03-07 08:55:00	2024-03-07	47000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
137	9	9	2024-03-20 15:30:00	2024-03-20	43000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
138	9	9	2024-04-02 10:05:00	2024-04-02	36000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
139	9	9	2024-04-15 17:40:00	2024-04-15	55000.00	9	8	Marriott	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
140	39	10	2024-01-02 09:15:00	2024-01-02	1200.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
141	24	11	2024-01-02 11:30:00	2024-01-02	890.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
142	12	12	2024-01-03 13:45:00	2024-01-03	2100.00	9	1	Пятёрочка	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
143	4	13	2024-01-04 18:20:00	2024-01-04	650.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
144	37	14	2024-01-05 09:00:00	2024-01-05	1450.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
145	14	15	2024-01-06 12:30:00	2024-01-06	3200.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
146	49	16	2024-01-06 14:15:00	2024-01-06	780.00	9	1	Пятёрочка	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
147	26	17	2024-01-07 10:50:00	2024-01-07	1100.00	9	1	Пятёрочка	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
148	2	18	2024-01-07 17:25:00	2024-01-07	2400.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
149	8	19	2024-01-08 08:40:00	2024-01-08	560.00	9	1	Пятёрочка	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
150	46	20	2024-01-09 19:10:00	2024-01-09	1800.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
151	38	21	2024-01-10 11:20:00	2024-01-10	920.00	9	1	Пятёрочка	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
152	1	22	2024-01-11 15:35:00	2024-01-11	3400.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
153	31	23	2024-01-12 09:55:00	2024-01-12	670.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
154	23	24	2024-01-13 18:00:00	2024-01-13	1550.00	9	1	Пятёрочка	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
155	28	25	2024-01-14 12:15:00	2024-01-14	2200.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
156	3	26	2024-01-15 10:30:00	2024-01-15	880.00	9	1	Пятёрочка	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
157	44	27	2024-01-16 16:45:00	2024-01-16	1700.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
158	18	28	2024-01-17 09:20:00	2024-01-17	430.00	9	1	Пятёрочка	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
159	13	29	2024-01-18 14:50:00	2024-01-18	2600.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
160	43	30	2024-01-19 11:05:00	2024-01-19	1350.00	9	1	Пятёрочка	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
161	20	31	2024-01-20 17:30:00	2024-01-20	790.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
162	48	32	2024-01-21 10:15:00	2024-01-21	1900.00	9	1	Пятёрочка	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
163	33	33	2024-01-22 13:40:00	2024-01-22	560.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
164	41	34	2024-01-23 08:55:00	2024-01-23	2800.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
165	39	10	2024-01-02 08:30:00	2024-01-02	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
166	24	11	2024-01-03 07:45:00	2024-01-03	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
167	12	12	2024-01-04 08:15:00	2024-01-04	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
168	4	13	2024-01-05 07:50:00	2024-01-05	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
169	37	14	2024-01-06 08:05:00	2024-01-06	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
170	14	15	2024-01-07 18:30:00	2024-01-07	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
171	49	16	2024-01-08 07:55:00	2024-01-08	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
172	26	17	2024-01-09 18:45:00	2024-01-09	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
173	2	18	2024-01-10 08:20:00	2024-01-10	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
174	8	19	2024-01-11 17:55:00	2024-01-11	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
175	46	20	2024-01-12 08:10:00	2024-01-12	55.00	9	9	Метро	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
176	38	21	2024-01-13 19:00:00	2024-01-13	55.00	9	9	Метро	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
177	1	22	2024-01-14 07:40:00	2024-01-14	55.00	9	9	Метро	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
178	31	23	2024-01-15 18:15:00	2024-01-15	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
179	23	24	2024-01-16 08:35:00	2024-01-16	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
180	28	25	2024-01-17 17:50:00	2024-01-17	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
181	3	26	2024-01-18 08:00:00	2024-01-18	55.00	9	9	Метро	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
182	44	27	2024-01-19 19:15:00	2024-01-19	55.00	9	9	Метро	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
183	18	28	2024-01-20 08:25:00	2024-01-20	55.00	9	9	Метро	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
184	13	29	2024-01-21 18:50:00	2024-01-21	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
185	15	35	2024-01-05 13:00:00	2024-01-05	4500.00	9	10	Кофемания	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
186	27	36	2024-01-06 20:30:00	2024-01-06	8900.00	9	10	Якитория	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
187	30	37	2024-01-07 14:15:00	2024-01-07	2300.00	9	10	Шоколадница	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
188	5	38	2024-01-12 19:45:00	2024-01-12	6700.00	9	10	Гинза	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
190	50	40	2024-01-14 20:00:00	2024-01-14	3400.00	9	10	Burger King	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
191	21	41	2024-01-19 14:45:00	2024-01-19	5200.00	9	10	Чайхона №1	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
192	34	42	2024-01-20 20:15:00	2024-01-20	2100.00	9	10	Теремок	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
193	45	43	2024-01-25 13:00:00	2024-01-25	7800.00	9	10	Новиков	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
194	11	44	2024-01-26 19:30:00	2024-01-26	1500.00	9	10	KFC	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
195	42	45	2024-01-27 14:15:00	2024-01-27	4300.00	9	10	Кофемания	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
196	10	46	2024-01-28 20:45:00	2024-01-28	9200.00	9	10	Белуга	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
197	22	47	2024-01-29 13:30:00	2024-01-29	2600.00	9	10	Шоколадница	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
198	7	48	2024-01-30 19:00:00	2024-01-30	3800.00	9	10	Якитория	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
199	17	49	2024-01-31 14:45:00	2024-01-31	1200.00	9	10	Burger King	8	purchase	declined	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
200	15	35	2024-01-08 07:30:00	2024-01-08	3200.00	9	3	Лукойл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
201	27	36	2024-01-10 16:45:00	2024-01-10	4100.00	9	3	Роснефть	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
202	30	37	2024-01-15 08:20:00	2024-01-15	2800.00	9	3	Газпромнефть	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
203	5	38	2024-01-17 17:00:00	2024-01-17	5600.00	9	3	Лукойл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
204	35	39	2024-01-22 07:45:00	2024-01-22	3900.00	9	3	Татнефть	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
205	50	40	2024-01-24 16:30:00	2024-01-24	4500.00	9	3	Роснефть	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
206	21	41	2024-01-26 08:10:00	2024-01-26	2600.00	9	3	Лукойл	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
207	34	42	2024-01-28 17:45:00	2024-01-28	3300.00	9	3	Газпромнефть	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
208	45	43	2024-01-30 07:55:00	2024-01-30	4800.00	9	3	Лукойл	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
209	11	44	2024-01-31 16:15:00	2024-01-31	2100.00	9	3	Роснефть	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
210	39	10	2024-02-01 10:20:00	2024-02-01	1650.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
211	24	11	2024-02-02 14:35:00	2024-02-02	980.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
212	12	12	2024-02-03 09:50:00	2024-02-03	2300.00	9	1	Пятёрочка	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
213	4	13	2024-02-05 18:05:00	2024-02-05	750.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
214	37	14	2024-02-07 11:20:00	2024-02-07	1400.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
215	14	15	2024-02-09 15:35:00	2024-02-09	3100.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
216	49	16	2024-02-10 09:50:00	2024-02-10	820.00	9	1	Пятёрочка	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
217	26	17	2024-02-12 17:05:00	2024-02-12	1250.00	9	1	Пятёрочка	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
218	2	18	2024-02-14 11:20:00	2024-02-14	2700.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
219	8	19	2024-02-16 15:35:00	2024-02-16	610.00	9	1	Пятёрочка	10	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
220	46	20	2024-02-17 09:50:00	2024-02-17	1900.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
221	38	21	2024-02-19 18:05:00	2024-02-19	870.00	9	1	Пятёрочка	4	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
222	1	22	2024-02-21 11:20:00	2024-02-21	3500.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
223	31	23	2024-02-23 15:35:00	2024-02-23	720.00	9	1	Пятёрочка	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
224	23	24	2024-02-24 09:50:00	2024-02-24	1600.00	9	1	Пятёрочка	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
225	28	25	2024-02-26 18:05:00	2024-02-26	2200.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
226	3	26	2024-02-27 11:20:00	2024-02-27	940.00	9	1	Пятёрочка	12	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
227	44	27	2024-02-28 15:35:00	2024-02-28	1750.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
228	18	28	2024-02-29 09:50:00	2024-02-29	480.00	9	1	Пятёрочка	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
229	13	29	2024-02-29 18:05:00	2024-02-29	2800.00	9	1	Пятёрочка	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
230	43	30	2024-02-01 07:40:00	2024-02-01	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
231	20	31	2024-02-02 18:55:00	2024-02-02	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
232	48	32	2024-02-05 08:10:00	2024-02-05	55.00	9	9	Метро	5	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
233	33	33	2024-02-07 19:25:00	2024-02-07	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
234	41	34	2024-02-09 07:40:00	2024-02-09	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
235	15	35	2024-02-12 18:55:00	2024-02-12	55.00	9	9	Метро	3	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
236	27	36	2024-02-14 08:10:00	2024-02-14	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
237	30	37	2024-02-16 19:25:00	2024-02-16	55.00	9	9	Метро	11	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
238	5	38	2024-02-19 07:40:00	2024-02-19	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
239	35	39	2024-02-21 18:55:00	2024-02-21	55.00	9	9	Метро	2	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
240	50	40	2024-02-23 08:10:00	2024-02-23	55.00	9	9	Метро	8	purchase	success	2026-06-20 11:13:30.423535	2026-06-20 11:13:30.423535	etl_user	f
\.


--
-- TOC entry 5516 (class 0 OID 16481)
-- Dependencies: 233
-- Data for Name: dict_card_products; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_card_products (card_product_id, product_code, product_name, product_category, product_tier, target_audience, min_age, max_age, annual_fee, cashback_base_rate, credit_limit_max, is_active, valid_from_dt, valid_to_dt, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	MULTI_CARD	Мультикарта	debit	standard	Все клиенты	18	\N	0.00	2.00	\N	t	2021-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	DEBIT_STUDENT	Студенческая карта	debit	standard	Студенты 14–25 лет	14	25	0.00	2.00	\N	t	2018-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	DEBIT_SILVER	Серебряная карта	debit	silver	Массовый сегмент	18	\N	599.00	2.00	\N	t	2017-06-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	DEBIT_PREMIUM	Премиальная карта	debit	premium	VIP-клиенты	21	\N	15000.00	5.00	\N	t	2019-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	CREDIT_CLASSIC	Классическая кредитная	credit	standard	Масс-сегмент	21	\N	1200.00	1.00	100000.00	t	2015-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	DEBIT_SALARY	Зарплатная карта	debit	standard	Зарплатные клиенты	18	\N	0.00	1.50	\N	t	2015-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	CREDIT_GOLD	Золотая кредитная карта	credit	gold	Масс-сегмент	21	\N	3500.00	3.00	300000.00	t	2016-06-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	DEBIT_CHILD	Детская карта	debit	standard	Дети 6–14 лет	6	14	0.00	1.00	\N	t	2018-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	CREDIT_TRAVEL	Тревел-карта	credit	gold	Путешественники	21	\N	4900.00	3.00	500000.00	t	2020-03-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	CREDIT_PLATINUM	Платиновая кредитная карта	credit	platinum	Premium-сегмент	21	\N	10000.00	5.00	1000000.00	t	2018-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	DEBIT_GOLD	Золотая дебетовая карта	debit	gold	Массовый сегмент	18	\N	3000.00	3.00	\N	t	2016-01-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	PREPAID_VIRTUAL	Виртуальная предоплаченная	prepaid	standard	Онлайн-покупки	14	\N	0.00	0.00	\N	t	2022-06-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
13	DEBIT_PENSIONER	Пенсионная карта	debit	standard	Пенсионеры от 55 лет	55	\N	0.00	3.00	\N	t	2019-09-01	\N	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5507 (class 0 OID 16395)
-- Dependencies: 224
-- Data for Name: dict_cities; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_cities (city_id, city_name, city_name_en, city_type, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Воронеж	Voronezh	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	Казань	Kazan	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	Новосибирск	Novosibirsk	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	Самара	Samara	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	Санкт-Петербург	Saint Petersburg	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	Пермь	Perm	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	Уфа	Ufa	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	Москва	Moscow	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	Ростов-на-Дону	Rostov-on-Don	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	Краснодар	Krasnodar	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	Екатеринбург	Yekaterinburg	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	Нижний Новгород	Nizhny Novgorod	city	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5509 (class 0 OID 16406)
-- Dependencies: 226
-- Data for Name: dict_currencies; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_currencies (currency_id, currency_code, currency_name_ru, currency_symbol, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	AMD	Армянский драм	֏	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	AED	Дирхам ОАЭ	د.إ	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	TRY	Турецкая лира	₺	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	EUR	Евро	€	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	CNY	Китайский юань	¥	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	CHF	Швейцарский франк	₣	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	KZT	Казахстанский тенге	₸	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	GBP	Британский фунт	£	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	RUB	Российский рубль	₽	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	USD	Доллар США	$	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	BYN	Белорусский рубль	Br	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5512 (class 0 OID 16428)
-- Dependencies: 229
-- Data for Name: dict_departments; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_departments (department_id, parent_department_id, city_id, department_name, department_code, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	\N	8	Отдел карточных продуктов	CARDS	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	\N	8	Отдел разработки	DEV	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	\N	8	Отдел аналитики данных	ANALYTICS	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	\N	8	Головной офис	HQ	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	\N	8	Отдел CRM и акций	CRM	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	4	3	Филиал Новосибирск	BRANCH_NSK	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	4	8	Департамент розничного бизнеса	RETAIL	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	4	8	Департамент маркетинга	MARKETING	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	4	8	Департамент рисков	RISK	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	4	11	Филиал Екатеринбург	BRANCH_EKB	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	4	8	Департамент информационных систем	IT	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	4	5	Филиал Санкт-Петербург	BRANCH_SPB	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5514 (class 0 OID 16451)
-- Dependencies: 231
-- Data for Name: dict_employees; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_employees (employee_id, department_id, city_id, manager_id, full_name, "position", role, email, hire_dt, fire_dt, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	4	8	\N	Иванов Алексей Петрович	Председатель правления	admin	ivanov@bank.ru	2010-03-01	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	3	8	\N	Зайцева Мария Олеговна	Аналитик данных	analyst	zaitseva@bank.ru	2021-07-01	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	2	8	\N	Соколов Артём Владимирович	Разработчик БД	developer	sokolov@bank.ru	2020-03-15	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	5	8	\N	Федорова Анна Михайловна	Руководитель CRM	manager	fedorova@bank.ru	2018-11-05	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	1	8	\N	Морозов Игорь Николаевич	Руководитель отдела карт	manager	morozov@bank.ru	2017-04-20	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	3	8	\N	Волков Павел Игоревич	Старший аналитик данных	analyst	volkov@bank.ru	2019-02-14	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	11	8	1	Новикова Екатерина Андреевна	ИТ-директор	admin	novikova@bank.ru	2014-09-01	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	12	5	1	Лебедева Наталья Юрьевна	Директор филиала СПб	manager	lebedeva@bank.ru	2016-08-22	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	6	3	1	Попов Сергей Алексеевич	Директор филиала НСК	manager	popov@bank.ru	2018-05-30	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	7	8	1	Смирнова Ольга Викторовна	Директор розничного бизнеса	manager	smirnova@bank.ru	2013-06-15	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	8	8	1	Козлов Дмитрий Сергеевич	Директор по маркетингу	manager	kozlov@bank.ru	2015-01-10	\N	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5510 (class 0 OID 16418)
-- Dependencies: 227
-- Data for Name: dict_mcc; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.dict_mcc (mcc_code, mcc_name, mcc_group, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
5411	Продуктовые магазины и супермаркеты	food	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5912	Аптеки	health	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5541	Автозаправочные станции	auto	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4112	Железнодорожный транспорт	transport	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5732	Электроника и бытовая техника	retail	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7832	Кинотеатры	entertainment	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5311	Универмаги	retail	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7011	Гостиницы и отели	travel	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4111	Городской транспорт	transport	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5812	Рестораны и кафе	food	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5999	Прочие магазины	other	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3000	Авиабилеты	travel	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5590 (class 0 OID 24587)
-- Dependencies: 307
-- Data for Name: ltv; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.ltv (product_name, all_clients, sum_transaction, ltv, report_date) FROM stdin;
Платиновая кредитная карта	15	447925.00	29861.67	2026-07-13
Тревел-карта	11	181510.00	16500.91	2026-07-13
Премиальная карта	28	154660.00	5523.57	2026-07-13
Золотая дебетовая карта	25	85035.00	3401.40	2026-07-13
Золотая кредитная карта	20	61890.00	3094.50	2026-07-13
Классическая кредитная	21	63490.00	3023.33	2026-07-13
Мультикарта	21	53925.00	2567.86	2026-07-13
Зарплатная карта	52	129760.00	2495.38	2026-07-13
Серебряная карта	28	61560.00	2198.57	2026-07-13
Студенческая карта	11	21670.00	1970.00	2026-07-13
Пенсионная карта	8	13760.00	1720.00	2026-07-13
\.


--
-- TOC entry 5589 (class 0 OID 17478)
-- Dependencies: 306
-- Data for Name: transaction_per_merchant; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.transaction_per_merchant (merchant_name, transaction_month, transaction_sum, avg_check, unique_clients_count, city_id) FROM stdin;
S7 Airlines	2024-02-01	10.00	89000.00	89000	1
Аэрофлот	2024-02-01	11.00	67000.00	67000	1
Marriott	2024-01-01	4.00	45000.00	45000	1
Radisson	2024-02-01	2.00	41000.00	41000	1
Hilton	2024-01-01	7.00	32000.00	32000	1
М.Видео	2024-01-01	12.00	28000.00	28000	1
Apple Store	2024-02-01	8.00	22000.00	22000	1
Эльдорадо	2024-02-01	4.00	18500.00	18500	1
DNS	2024-01-01	8.00	15000.00	15000	1
Massimo Dutti	2024-02-01	9.00	13500.00	13500	1
Туттиairlines	2024-01-01	1.00	12000.00	12000	1
Adidas	2024-01-01	6.00	9800.00	9800	1
Zara	2024-01-01	3.00	8500.00	8500	1
Nike	2024-02-01	7.00	7600.00	7600	1
H&M	2024-01-01	8.00	6700.00	6700	1
Ginza	2024-02-01	11.00	5800.00	5800	1
Burger King	2024-01-01	10.00	5600.00	5600	1
Роснефть	2024-02-01	3.00	5100.00	5100	1
Макдоналдс	2024-02-01	6.00	4500.00	4500	1
KFC	2024-01-01	4.00	4200.00	4200	1
Теремок	2024-02-01	10.00	3900.00	3900	1
Лукойл	2024-01-01	7.00	3400.00	3400	1
Кофемания	2024-01-01	5.00	3200.00	3200	1
BP	2024-02-01	5.00	3100.00	3100	1
Якитория	2024-01-01	8.00	2800.00	2800	1
Шоколадница	2024-01-01	5.00	2300.00	2300	1
Sunlight	2024-02-01	9.00	2200.00	2200	1
Аптека 36.6	2024-01-01	2.00	2100.00	2100	1
Вкусвилл	2024-02-01	1.00	1900.00	1900	1
Ригла	2024-01-01	11.00	1800.00	1800	1
Леруа Мерлен	2024-02-01	4.00	1750.00	1750	1
Читай-город	2024-01-01	1.00	1650.00	1650	1
Пятёрочка	2024-01-01	8.00	1500.00	1500	1
Перекрёсток	2024-02-01	2.00	1350.00	1350	1
Лента	2024-01-01	9.00	1200.00	1200	1
Газпромнефть	2024-01-01	9.00	1100.00	1100	1
Ашан	2024-01-01	3.00	980.00	980	1
Fix Price	2024-01-01	6.00	890.00	890	1
Красное&Белое	2024-02-01	3.00	850.00	850	1
Планета здоровья	2024-02-01	12.00	780.00	780	1
Дикси	2024-01-01	10.00	760.00	760	1
Магнит	2024-01-01	12.00	700.00	700	1
Метро	2024-02-01	12.00	620.00	620	1
Автобус	2024-01-01	2.00	550.00	550	1
Метро	2024-01-01	11.00	450.00	450	1
Трамвай	2024-02-01	5.00	430.00	430	1
\.


--
-- TOC entry 5588 (class 0 OID 17465)
-- Dependencies: 305
-- Data for Name: transaction_sum; Type: TABLE DATA; Schema: md; Owner: postgres
--

COPY md.transaction_sum (product_code, count_card, transaction_dt, transaction_sum) FROM stdin;
\.


--
-- TOC entry 5557 (class 0 OID 16852)
-- Dependencies: 274
-- Data for Name: campaign_clients; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.campaign_clients (campaign_client_id, campaign_id, client_id, card_id, enrollment_dttm, status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	10	39	48	2024-02-03 12:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	5	16	9	2024-02-16 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	10	40	47	2024-02-02 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	3	36	10	2024-03-03 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	3	50	8	2024-03-02 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	8	27	24	2024-02-03 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	9	17	44	2024-01-02 08:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	2	33	3	2024-01-17 10:15:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	7	12	49	2024-03-03 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	1	35	1	2024-01-03 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
11	5	24	4	2024-02-17 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
12	2	43	6	2024-01-16 09:30:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
13	9	49	45	2024-01-03 09:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
14	8	6	29	2024-02-02 08:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
15	6	31	19	2024-01-03 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
16	1	5	2	2024-01-02 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
17	4	3	12	2024-01-02 12:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
18	4	44	13	2024-01-03 13:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
19	7	34	32	2024-03-02 10:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
20	6	48	25	2024-01-04 11:00:00	active	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5559 (class 0 OID 16877)
-- Dependencies: 276
-- Data for Name: campaign_rewards; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.campaign_rewards (reward_id, campaign_id, client_id, transaction_id, reward_amount, reward_dt, reward_status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	1	5	45	22.00	2024-01-23	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	8	6	21	84.00	2024-01-10	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	6	31	30	45.00	2024-01-06	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	8	27	26	136.00	2024-01-16	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	4	3	36	840.00	2024-01-17	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	4	44	35	4690.00	2024-02-04	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	10	39	3	136.50	2024-02-07	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	2	33	44	140.00	2024-01-31	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	5	24	43	53.40	2024-02-18	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	9	17	7	21.50	2024-02-02	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
11	3	36	38	1350.00	2024-03-04	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
12	2	43	41	22.50	2024-01-09	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
13	3	50	40	2800.00	2024-03-03	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
14	10	40	4	196.00	2024-02-03	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
15	7	12	2	49.00	2024-03-03	pending	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
16	7	34	18	750.00	2024-03-02	pending	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
17	9	49	6	31.00	2024-02-18	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
18	1	35	46	44.00	2024-01-27	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
19	5	16	39	2700.00	2024-02-17	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
20	6	48	25	21.00	2024-01-12	paid	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5555 (class 0 OID 16825)
-- Dependencies: 272
-- Data for Name: campaigns; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.campaigns (campaign_id, campaign_name, campaign_type, start_dt, end_dt, target_segment, card_product_id, reward_rate, budget, currency_id, owner_employee_id, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Бонусы для пенсионеров	bonus	2024-01-01	2024-12-31	pensioner	14	4.00	150000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
2	Бонусы за рестораны	bonus	2024-01-15	2024-04-15	premium	11	5.00	300000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
3	Платинум привилегии	cashback	2024-03-01	2024-06-30	vip	10	10.00	2000000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
4	Миль за путешествия	miles	2024-01-01	2024-06-30	premium	9	7.00	1000000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
5	Бонусы за электронику	bonus	2024-02-15	2024-04-30	premium	7	6.00	800000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
6	Кэшбэк на продукты	cashback	2024-01-01	2024-03-31	mass	6	3.00	500000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
7	Кэшбэк на одежду	cashback	2024-03-01	2024-05-31	mass	4	5.00	600000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
8	Кэшбэк на АЗС	cashback	2024-02-01	2024-05-31	mass	3	4.00	400000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
9	Кэшбэк для студентов	cashback	2024-01-01	2024-12-31	student	2	5.00	200000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
10	Кэшбэк мультикарта	cashback	2024-02-01	2024-07-31	mass	1	3.50	350000.00	9	\N	2026-06-17 21:53:22.53347	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5551 (class 0 OID 16765)
-- Dependencies: 268
-- Data for Name: cards; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.cards (card_id, client_id, card_product_id, card_number_hash, card_status, open_dt, close_dt, expiry_dt, credit_limit, currency_id, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	22	14	c1262a319362dc7e46c2999968eb253a	active	2020-08-14	\N	2025-08-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	18	14	ad21653fb3d470a799eba9968537a34b	active	2021-12-28	\N	2026-12-28	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	26	11	46f11768f7cef80132f6ff8c6843a058	active	2020-07-31	\N	2025-07-31	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	13	11	1a655a3c9acf92ba96c3cbd01056a6e4	active	2021-03-08	\N	2026-03-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	38	11	455febaf1a66ab9ada96bbb04c66a325	active	2022-09-24	\N	2027-09-24	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	4	11	31ce0ae7081e61d01e17f4fbcd0382e0	active	2022-05-18	\N	2027-05-18	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	48	11	cc2739e03a55a2baf5079f4ab0f7b314	active	2022-04-08	\N	2027-04-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	19	10	08d29326c1e2fed2fd468254df8f1f52	active	2020-06-07	\N	2025-06-07	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	9	10	c2335bc3483ee04fa170be79301f1766	active	2020-04-21	\N	2025-04-21	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	46	10	8bd40b59e1a7bffb3a661ae5809f05c3	active	2019-05-27	\N	2024-05-27	1000000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	44	9	853edf9fd145780210f8aeb2501495e0	active	2020-03-23	\N	2025-03-23	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	12	9	2c57c22c3172340709206b69b09af91e	active	2022-10-25	\N	2027-10-25	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
13	29	9	3ea95560ccca60e8538adc55f99a6edd	active	2021-06-04	\N	2026-06-04	500000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
14	15	7	74ba39b275456d6c87e5ad2ba7ba0d9c	active	2019-11-12	\N	2024-11-12	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
15	35	7	f0d7fb9fb2fe112c0321d9e53120ff94	active	2019-12-01	\N	2024-12-01	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
16	3	7	b7ffd93b27884ecb1026947e7514ed3d	active	2019-07-10	\N	2024-07-10	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
17	49	7	f2d81545d56b9a97be8cd346f2f069b3	active	2020-09-21	\N	2025-09-21	300000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
18	28	6	d9cb5930f320f334fa0691efc85e845f	active	2019-11-20	\N	2024-11-20	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
19	1	6	86463a6cac402bfda0d381168d46554f	active	2020-01-15	\N	2025-01-15	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
20	31	6	f26838f490873e4ffa6c10000f29372d	blocked	2018-01-27	\N	2023-01-27	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
21	41	6	2d6bbb7f244cbec701170225aa044d23	active	2019-07-08	\N	2024-07-08	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
22	47	6	b8976f5ac7c42d377f16f782bdf29377	blocked	2017-12-16	\N	2022-12-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
23	24	6	1b4dfbdd4d8bba68eec217b639d070ca	active	2022-10-06	\N	2027-10-06	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
24	11	6	051cd84fb9cc5d41b297f789c97179c8	active	2019-02-17	\N	2024-02-17	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
25	7	6	f2e35014b9478d853b50c8e599ccf1ac	active	2018-06-30	\N	2023-06-30	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
26	17	6	2e37bca84257c2f1bb6e2ec31ed3129e	blocked	2017-09-16	\N	2022-09-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
27	36	6	bd54775ae3dff3c32650a4d55ef687f7	active	2021-06-18	\N	2026-06-18	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
28	25	5	4db4802622eaf31ea48bfcbfeedb270c	active	2021-02-18	\N	2026-02-18	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
29	5	5	2cbf08d6d6c2b31b94d36cb7f3f29275	active	2020-09-27	\N	2025-09-27	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
30	37	5	6dc774b4932a7d7bb6d38f976f16ddbb	active	2020-02-07	\N	2025-02-07	100000.00	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
31	23	4	c14c8ff146dc25cf2cff54334f7417a8	active	2019-03-29	\N	2024-03-29	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
32	6	4	a2e92e7ae62a8f49f3cfad77fd73e09e	active	2021-01-14	\N	2026-01-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
33	33	4	40556da66f53c530af922e2a5771740d	active	2020-08-22	\N	2025-08-22	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
34	42	4	4dbf0d5b7af1473e4510e2703ae8c7e5	active	2021-01-19	\N	2026-01-19	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
35	39	4	34f7afa3384d9e9362c7a1f81dba1d74	active	2021-04-12	\N	2026-04-12	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
36	50	4	dfe5c842ed015ea49d664ca6a33ac7d2	active	2021-02-14	\N	2026-02-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
37	14	4	1019ec9d35eccc7f727164f02827ae71	active	2020-07-19	\N	2025-07-19	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
38	21	3	2fb94a26ea921b25e3cfaf83a7d23f86	active	2021-05-11	\N	2026-05-11	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
39	10	3	13c76899fb85e6d585ac7dca0f1592e4	active	2021-08-05	\N	2026-08-05	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
40	2	3	b77db32220b56a5015adc16bcb974ff8	active	2021-03-22	\N	2026-03-22	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
41	34	3	ded0c48d679491231b7a90f78783a04b	active	2022-03-16	\N	2027-03-16	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
42	45	3	f6f59ab82bae5b8acaad2fe7489888a3	active	2021-10-14	\N	2026-10-14	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
43	30	3	44e09a74c39ed9d9b80f2bedd5181d32	active	2022-09-13	\N	2027-09-13	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
44	27	2	fe60d9deb07c243a2ebbe1c4f0eb8fa4	active	2022-04-15	\N	2027-04-15	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
45	43	2	4c381c194283ed3fdda088402a7d1e22	active	2022-08-30	\N	2027-08-30	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
46	20	2	1118c8a912757d2b1069a2ad974dfcce	active	2022-01-23	\N	2027-01-23	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
47	8	1	d17176b613a57a9f6cbb35bc1638b11f	active	2022-12-09	\N	2027-12-09	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
48	32	1	63a60d5282c045c2759f59f31b91ecf3	active	2021-05-09	\N	2026-05-09	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
49	16	1	cccab353dbd4c89f5025a47b2c182284	active	2022-04-03	\N	2027-04-03	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
50	40	1	d7071917a1bdad1dcc649d7c6f6171cb	active	2022-11-05	\N	2027-11-05	\N	9	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5549 (class 0 OID 16749)
-- Dependencies: 266
-- Data for Name: clients; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.clients (client_id, full_name, birth_dt, gender, city_id, segment, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Зубова Анастасия Николаевна	1995-04-08	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
2	Гусева Людмила Аркадьевна	1960-06-18	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
3	Кузнецова Ирина Борисовна	1969-10-25	F	1	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
4	Никитина Галина Романовна	1989-10-06	F	1	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
5	Белова Тамара Ивановна	1958-12-28	F	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
6	Морозов Игорь Николаевич	1982-09-27	M	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
7	Кириллова Жанна Олеговна	1987-01-19	F	2	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
8	Воробьева Алина Константиновна	2000-09-13	F	2	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
9	Козлов Дмитрий Сергеевич	1978-11-03	M	3	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
10	Матвеева Полина Игоревна	1996-11-05	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
11	Фролова Оксана Владимировна	1973-11-20	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
12	Орлова Юлия Евгеньевна	1996-04-03	F	3	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
13	Тарасов Георгий Михайлович	1968-08-22	M	4	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
14	Тихонов Максим Юрьевич	1984-05-11	M	4	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
15	Назаров Олег Викторович	1983-10-14	M	4	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
16	Соколов Артём Владимирович	1975-04-21	M	4	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
17	Логинов Илья Станиславович	1998-04-15	M	5	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
18	Захаров Андрей Олегович	1979-11-12	M	5	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
19	Осипов Леонид Борисович	1981-04-12	M	5	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
20	Смирнова Ольга Викторовна	1990-07-22	F	5	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
21	Ильин Станислав Романович	1989-02-07	M	6	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
22	Борисов Евгений Анатольевич	1992-02-18	M	6	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
23	Герасимов Антон Леонидович	1970-09-21	M	6	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
24	Михайлов Роман Дмитриевич	1994-03-08	M	6	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
25	Калинин Руслан Дмитриевич	1986-12-16	M	7	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
26	Ефимов Константин Аркадьевич	1977-03-29	M	7	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
27	Попов Сергей Алексеевич	1983-02-17	M	7	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
28	Королёв Артур Васильевич	1985-12-01	M	7	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
29	Щербакова Вероника Павловна	1993-09-24	F	8	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
30	Петрова Светлана Александровна	1987-07-19	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
31	Иванов Алексей Петрович	1985-03-15	M	8	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
32	Соловьева Регина Аркадьевна	1988-02-14	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
33	Комарова Елена Дмитриевна	1980-07-31	F	8	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
34	Федорова Анна Михайловна	1993-01-14	F	8	vip	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
35	Громова Надежда Петровна	1962-08-14	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
36	Медведева Татьяна Сергеевна	1991-05-27	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
37	Панова Кристина Евгеньевна	1997-03-16	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
38	Лебедева Наталья Юрьевна	1991-08-05	F	9	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
39	Сергеева Дарья Николаевна	1994-05-09	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
40	Зайцева Мария Олеговна	1997-12-09	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
41	Антонова Валерия Сергеевна	1999-01-23	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
42	Савельева Марина Юрьевна	1978-03-23	F	10	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
43	Новикова Екатерина Андреевна	1995-05-18	F	11	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
44	Куликов Денис Игоревич	1991-06-04	M	11	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
45	Степанов Виктор Павлович	1971-09-16	M	11	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
46	Громов Василий Петрович	1974-07-08	M	11	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
47	Макаров Владислав Олегович	1976-01-27	M	12	mass	f	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
48	Волков Павел Игоревич	1988-06-30	M	12	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
49	Беляев Тимур Александрович	1999-08-30	M	12	mass	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
50	Крылов Николай Федорович	1986-06-07	M	12	premium	t	2026-06-14 22:00:02.135489	2026-06-14 22:00:02.135489	etl_user	f
\.


--
-- TOC entry 5547 (class 0 OID 16732)
-- Dependencies: 264
-- Data for Name: dict_card_products; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_card_products (card_product_id, product_code, product_name, product_category, product_tier, target_audience, min_age, max_age, annual_fee, cashback_base_rate, credit_limit_max, is_active, valid_from_dt, valid_to_dt, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	MULTI_CARD	Мультикарта	debit	standard	Все клиенты	18	\N	0.00	2.00	\N	t	2021-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
2	DEBIT_STUDENT	Студенческая карта	debit	standard	Студенты 14–25 лет	14	25	0.00	2.00	\N	t	2018-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3	DEBIT_SILVER	Серебряная карта	debit	silver	Массовый сегмент	18	\N	599.00	2.00	\N	t	2017-06-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4	DEBIT_PREMIUM	Премиальная карта	debit	premium	VIP-клиенты	21	\N	15000.00	5.00	\N	t	2019-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5	CREDIT_CLASSIC	Классическая кредитная	credit	standard	Масс-сегмент	21	\N	1200.00	1.00	100000.00	t	2015-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
6	DEBIT_SALARY	Зарплатная карта	debit	standard	Зарплатные клиенты	18	\N	0.00	1.50	\N	t	2015-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7	CREDIT_GOLD	Золотая кредитная карта	credit	gold	Масс-сегмент	21	\N	3500.00	3.00	300000.00	t	2016-06-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
8	DEBIT_CHILD	Детская карта	debit	standard	Дети 6–14 лет	6	14	0.00	1.00	\N	t	2018-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
9	CREDIT_TRAVEL	Тревел-карта	credit	gold	Путешественники	21	\N	4900.00	3.00	500000.00	t	2020-03-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
10	CREDIT_PLATINUM	Платиновая кредитная карта	credit	platinum	Premium-сегмент	21	\N	10000.00	5.00	1000000.00	t	2018-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
11	DEBIT_GOLD	Золотая дебетовая карта	debit	gold	Массовый сегмент	18	\N	3000.00	3.00	\N	t	2016-01-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
12	PREPAID_VIRTUAL	Виртуальная предоплаченная	prepaid	standard	Онлайн-покупки	14	\N	0.00	0.00	\N	t	2022-06-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
13	CREDIT_CLASSIC_V1	Классическая кредитная (old)	credit	standard	Масс-сегмент (архив)	21	\N	900.00	0.50	50000.00	f	2010-01-01	2014-12-31	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
14	DEBIT_PENSIONER	Пенсионная карта	debit	standard	Пенсионеры от 55 лет	55	\N	0.00	3.00	\N	t	2019-09-01	\N	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5538 (class 0 OID 16646)
-- Dependencies: 255
-- Data for Name: dict_cities; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_cities (city_id, city_name, city_name_en, city_type, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	Воронеж	Voronezh	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
2	Казань	Kazan	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3	Новосибирск	Novosibirsk	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4	Самара	Samara	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5	Санкт-Петербург	Saint Petersburg	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
6	Пермь	Perm	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7	Уфа	Ufa	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
8	Москва	Moscow	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
9	Ростов-на-Дону	Rostov-on-Don	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
10	Краснодар	Krasnodar	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
11	Екатеринбург	Yekaterinburg	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
12	Нижний Новгород	Nizhny Novgorod	city	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5540 (class 0 OID 16657)
-- Dependencies: 257
-- Data for Name: dict_currencies; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_currencies (currency_id, currency_code, currency_name_ru, currency_symbol, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	AMD	Армянский драм	֏	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
2	AED	Дирхам ОАЭ	د.إ	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3	TRY	Турецкая лира	₺	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4	EUR	Евро	€	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5	CNY	Китайский юань	¥	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
6	CHF	Швейцарский франк	₣	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7	KZT	Казахстанский тенге	₸	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
8	GBP	Британский фунт	£	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
9	RUB	Российский рубль	₽	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
10	USD	Доллар США	$	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
11	JPY	Японская иена	¥	f	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
12	BYN	Белорусский рубль	Br	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5543 (class 0 OID 16679)
-- Dependencies: 260
-- Data for Name: dict_departments; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_departments (department_id, parent_department_id, city_id, department_name, department_code, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	\N	8	Головной офис	HQ	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
2	1	11	Филиал Екатеринбург	BRANCH_EKB	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3	1	8	Департамент розничного бизнеса	RETAIL	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4	1	8	Департамент маркетинга	MARKETING	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5	1	8	Департамент рисков	RISK	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
6	1	8	Департамент информационных систем	IT	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7	1	5	Филиал Санкт-Петербург	BRANCH_SPB	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
8	1	3	Филиал Новосибирск	BRANCH_NSK	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
9	\N	8	Отдел аналитики данных	ANALYTICS	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
10	\N	8	Отдел разработки	DEV	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
11	\N	8	Отдел CRM и акций	CRM	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
12	\N	8	Отдел карточных продуктов	CARDS	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5545 (class 0 OID 16702)
-- Dependencies: 262
-- Data for Name: dict_employees; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_employees (employee_id, department_id, city_id, manager_id, full_name, "position", role, email, hire_dt, fire_dt, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	1	8	\N	Иванов Алексей Петрович	Председатель правления	admin	ivanov@bank.ru	2010-03-01	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
2	8	3	1	Попов Сергей Алексеевич	Директор филиала НСК	manager	popov@bank.ru	2018-05-30	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3	7	5	1	Лебедева Наталья Юрьевна	Директор филиала СПб	manager	lebedeva@bank.ru	2016-08-22	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4	9	8	\N	Волков Павел Игоревич	Старший аналитик данных	analyst	volkov@bank.ru	2019-02-14	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5	12	8	\N	Морозов Игорь Николаевич	Руководитель отдела карт	manager	morozov@bank.ru	2017-04-20	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
6	11	8	\N	Федорова Анна Михайловна	Руководитель CRM	manager	fedorova@bank.ru	2018-11-05	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7	10	8	\N	Соколов Артём Владимирович	Разработчик БД	developer	sokolov@bank.ru	2020-03-15	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
8	4	8	1	Козлов Дмитрий Сергеевич	Директор по маркетингу	manager	kozlov@bank.ru	2015-01-10	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
9	3	8	1	Смирнова Ольга Викторовна	Директор розничного бизнеса	manager	smirnova@bank.ru	2013-06-15	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
10	9	8	\N	Зайцева Мария Олеговна	Аналитик данных	analyst	zaitseva@bank.ru	2021-07-01	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
11	5	8	1	Кузнецова Ирина Борисовна	Директор по рискам	manager	kuznetsova@bank.ru	2012-10-17	2024-12-31	f	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
12	6	8	1	Новикова Екатерина Андреевна	ИТ-директор	admin	novikova@bank.ru	2014-09-01	\N	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5541 (class 0 OID 16669)
-- Dependencies: 258
-- Data for Name: dict_mcc; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.dict_mcc (mcc_code, mcc_name, mcc_group, is_active, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
5411	Продуктовые магазины и супермаркеты	food	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5912	Аптеки	health	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5541	Автозаправочные станции	auto	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4112	Железнодорожный транспорт	transport	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5732	Электроника и бытовая техника	retail	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7832	Кинотеатры	entertainment	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5311	Универмаги	retail	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
7011	Гостиницы и отели	travel	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
4111	Городской транспорт	transport	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5812	Рестораны и кафе	food	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
5999	Прочие магазины	other	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
3000	Авиабилеты	travel	t	2026-06-14 16:39:32.915353	2026-06-14 16:39:32.915353	etl_user	f
\.


--
-- TOC entry 5553 (class 0 OID 16790)
-- Dependencies: 270
-- Data for Name: transactions; Type: TABLE DATA; Schema: ods; Owner: postgres
--

COPY ods.transactions (transaction_id, card_id, client_id, transaction_dttm, transaction_dt, amount, currency_id, mcc_code, merchant_name, city_id, transaction_type, status, created_dttm, updated_dttm, created_by, is_deleted) FROM stdin;
1	50	40	2024-02-14 10:35:00	2024-02-14	850.00	9	5411	Красное&Белое	3	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
2	49	16	2024-01-20 14:50:00	2024-01-20	980.00	9	5411	Ашан	3	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
3	48	32	2024-02-06 14:40:00	2024-02-06	3900.00	9	5812	Теремок	10	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
4	47	8	2024-01-12 08:30:00	2024-01-12	5600.00	9	5812	Burger King	10	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
5	46	20	2024-01-24 08:15:00	2024-01-24	760.00	9	5411	Дикси	10	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
6	45	43	2024-02-17 15:50:00	2024-02-17	620.00	9	4111	Метро	12	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
7	44	27	2024-02-01 16:30:00	2024-02-01	430.00	9	4111	Трамвай	5	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
8	43	30	2024-02-04 17:10:00	2024-02-04	1350.00	9	5411	Перекрёсток	2	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
9	42	45	2024-02-19 16:20:00	2024-02-19	1750.00	9	5999	Леруа Мерлен	4	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
10	41	34	2024-02-08 15:15:00	2024-02-08	2200.00	9	5999	Sunlight	9	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
11	40	2	2024-01-06 12:45:00	2024-01-06	3200.00	9	5812	Кофемания	5	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
12	39	10	2024-01-14 13:00:00	2024-01-14	1200.00	9	5411	Лента	9	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
13	38	21	2024-01-25 13:40:00	2024-01-25	4200.00	9	5812	KFC	4	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
14	37	14	2024-01-18 17:20:00	2024-01-18	6700.00	9	\N	H&M	8	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
15	35	39	2024-02-13 17:50:00	2024-02-13	3100.00	9	5541	BP	5	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
16	34	42	2024-02-16 09:05:00	2024-02-16	41000.00	9	7011	Radisson	2	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
17	33	33	2024-02-07 09:25:00	2024-02-07	18500.00	9	5732	Эльдорадо	4	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
18	32	6	2024-01-10 11:20:00	2024-01-10	15000.00	9	5732	DNS	8	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
19	31	23	2024-01-27 15:55:00	2024-01-27	32000.00	9	7011	Hilton	7	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
20	30	37	2024-02-11 08:20:00	2024-02-11	4500.00	9	5812	Макдоналдс	6	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
21	29	5	2024-01-09 18:00:00	2024-01-09	2100.00	9	5912	Аптека 36.6	2	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
22	28	25	2024-01-29 14:15:00	2024-01-29	9800.00	9	\N	Adidas	6	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
23	27	36	2024-02-10 16:35:00	2024-02-10	1900.00	9	5411	Вкусвилл	1	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
24	26	17	2024-01-21 11:35:00	2024-01-21	1800.00	9	5912	Ригла	11	purchase	declined	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
25	25	7	2024-01-11 16:45:00	2024-01-11	700.00	9	5411	Магнит	12	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
26	24	11	2024-01-15 10:45:00	2024-01-15	3400.00	9	5541	Лукойл	7	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
27	23	24	2024-01-28 09:30:00	2024-01-28	1650.00	9	5999	Читай-город	1	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
28	21	41	2024-02-15 14:20:00	2024-02-15	5800.00	9	5812	Ginza	11	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
29	20	31	2024-02-05 10:55:00	2024-02-05	780.00	9	5912	Планета здоровья	12	purchase	declined	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
30	19	1	2024-01-05 10:23:00	2024-01-05	1500.00	9	5411	Пятёрочка	8	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
31	18	28	2024-02-02 08:45:00	2024-02-02	5100.00	9	5541	Роснефть	3	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
32	16	3	2024-01-07 09:15:00	2024-01-07	8500.00	9	\N	Zara	3	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
33	15	35	2024-02-09 11:50:00	2024-02-09	7600.00	9	\N	Nike	7	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
34	14	15	2024-01-19 12:10:00	2024-01-19	2300.00	9	5812	Шоколадница	5	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
35	13	29	2024-02-03 12:20:00	2024-02-03	67000.00	9	\N	Аэрофлот	11	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
36	12	12	2024-01-16 15:30:00	2024-01-16	12000.00	9	\N	Туттиairlines	1	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
37	11	44	2024-02-18 11:35:00	2024-02-18	89000.00	9	\N	S7 Airlines	10	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
38	10	46	2024-02-20 08:05:00	2024-02-20	13500.00	9	\N	Massimo Dutti	9	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
39	9	9	2024-01-13 20:15:00	2024-01-13	45000.00	9	7011	Marriott	4	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
40	8	19	2024-01-23 19:25:00	2024-01-23	28000.00	9	5732	М.Видео	12	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
41	6	4	2024-01-08 14:30:00	2024-01-08	450.00	9	4111	Метро	11	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
42	5	38	2024-02-12 13:05:00	2024-02-12	22000.00	9	5732	Apple Store	8	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
43	4	13	2024-01-17 09:00:00	2024-01-17	890.00	9	5999	Fix Price	6	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
44	3	26	2024-01-30 11:00:00	2024-01-30	2800.00	9	5812	Якитория	8	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
45	2	18	2024-01-22 16:00:00	2024-01-22	550.00	9	4111	Автобус	2	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
46	1	22	2024-01-26 10:05:00	2024-01-26	1100.00	9	5541	Газпромнефть	9	purchase	success	2026-06-16 18:27:43.70565	2026-06-16 18:27:43.70565	etl_user	f
47	19	1	2024-01-18 09:15:00	2024-01-18	3200.00	9	5812	Кофемания	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
48	19	1	2024-01-25 14:40:00	2024-01-25	450.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
49	19	1	2024-02-03 11:20:00	2024-02-03	8700.00	9	5732	DNS	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
50	19	1	2024-02-14 18:30:00	2024-02-14	2100.00	9	5912	Аптека 36.6	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
51	19	1	2024-02-28 13:05:00	2024-02-28	980.00	9	5411	Магнит	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
52	19	1	2024-03-07 09:50:00	2024-03-07	15000.00	9	5311	ЦУМ	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
53	19	1	2024-03-15 16:25:00	2024-03-15	560.00	9	5812	Шоколадница	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
54	19	1	2024-03-22 12:10:00	2024-03-22	1200.00	9	5411	Вкусвилл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
55	19	1	2024-04-02 08:45:00	2024-04-02	450.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
56	19	1	2024-04-11 17:30:00	2024-04-11	4500.00	9	5812	Якитория	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
57	19	1	2024-04-20 10:15:00	2024-04-20	780.00	9	5912	Ригла	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
58	19	1	2024-05-05 14:00:00	2024-05-05	1650.00	9	5411	Перекрёсток	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
59	19	1	2024-05-18 19:20:00	2024-05-18	350.00	9	7832	Синема Парк	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
60	40	2	2024-01-19 10:30:00	2024-01-19	1100.00	9	5411	Лента	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
61	40	2	2024-02-01 15:15:00	2024-02-01	2800.00	9	5541	Лукойл	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
62	40	2	2024-02-12 09:40:00	2024-02-12	650.00	9	4111	Автобус	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
63	40	2	2024-02-24 17:55:00	2024-02-24	12000.00	9	5311	Галерея	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
64	40	2	2024-03-08 11:20:00	2024-03-08	890.00	9	5912	Планета здоровья	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
65	40	2	2024-03-19 14:35:00	2024-03-19	4100.00	9	5812	Burger King	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
66	40	2	2024-04-03 08:10:00	2024-04-03	1900.00	9	5411	Пятёрочка	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
67	40	2	2024-04-15 16:45:00	2024-04-15	560.00	9	4111	Трамвай	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
68	40	2	2024-04-28 12:20:00	2024-04-28	7600.00	9	5732	М.Видео	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
69	40	2	2024-05-10 10:05:00	2024-05-10	2300.00	9	5812	Теремок	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
70	40	2	2024-05-22 18:30:00	2024-05-22	450.00	9	7832	Аврора	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
71	16	3	2024-01-21 14:50:00	2024-01-21	1200.00	9	5411	Магнит	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
72	16	3	2024-02-05 11:25:00	2024-02-05	3400.00	9	5541	Роснефть	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
73	16	3	2024-02-18 16:40:00	2024-02-18	780.00	9	5912	Аптека 36.6	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
74	16	3	2024-03-02 09:05:00	2024-03-02	2600.00	9	5812	KFC	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
75	16	3	2024-03-14 13:30:00	2024-03-14	450.00	9	4111	Метро	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
76	16	3	2024-03-27 18:15:00	2024-03-27	11000.00	9	5732	Эльдорадо	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
77	16	3	2024-04-08 10:50:00	2024-04-08	1500.00	9	5411	Вкусвилл	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
78	16	3	2024-04-22 15:25:00	2024-04-22	4800.00	9	5812	Гинза	3	purchase	declined	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
79	16	3	2024-05-06 09:00:00	2024-05-06	1800.00	9	5999	Fix Price	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
80	16	3	2024-05-20 14:35:00	2024-05-20	650.00	9	5912	Ригла	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
81	6	4	2024-01-22 10:15:00	2024-01-22	2300.00	9	5812	Шоколадница	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
82	6	4	2024-02-04 16:50:00	2024-02-04	1100.00	9	5411	Перекрёсток	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
83	6	4	2024-02-16 09:25:00	2024-02-16	4500.00	9	5541	Газпромнефть	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
84	6	4	2024-02-27 14:00:00	2024-02-27	8900.00	9	5311	Гринвич	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
85	6	4	2024-03-10 11:35:00	2024-03-10	560.00	9	5912	Планета здоровья	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
86	6	4	2024-03-23 17:10:00	2024-03-23	3200.00	9	5812	Якитория	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
87	6	4	2024-04-05 08:45:00	2024-04-05	1700.00	9	5411	Лента	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
88	6	4	2024-04-18 15:20:00	2024-04-18	13000.00	9	5732	DNS	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
89	6	4	2024-05-01 10:55:00	2024-05-01	450.00	9	4111	Автобус	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
90	6	4	2024-05-14 16:30:00	2024-05-14	2800.00	9	5812	Burger King	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
91	6	4	2024-05-27 12:05:00	2024-05-27	900.00	9	5999	Читай-город	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
92	29	5	2024-01-23 11:35:00	2024-01-23	3400.00	9	5541	Лукойл	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
93	29	5	2024-02-06 08:10:00	2024-02-06	1300.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
94	29	5	2024-02-19 14:45:00	2024-02-19	5600.00	9	5812	Чайхона №1	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
95	29	5	2024-03-03 10:20:00	2024-03-03	450.00	9	4111	Метро	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
96	29	5	2024-03-16 16:55:00	2024-03-16	9800.00	9	5311	Мега	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
97	29	5	2024-03-29 12:30:00	2024-03-29	2700.00	9	5541	Татнефть	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
98	29	5	2024-04-10 09:05:00	2024-04-10	1600.00	9	5411	Магнит	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
99	29	5	2024-04-23 15:40:00	2024-04-23	4200.00	9	5812	KFC	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
100	29	5	2024-05-07 11:15:00	2024-05-07	780.00	9	5912	Ригла	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
101	29	5	2024-05-19 17:50:00	2024-05-19	6200.00	9	5732	Samsung	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
102	29	5	2024-05-28 08:25:00	2024-05-28	1100.00	9	5411	Вкусвилл	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
103	29	5	2024-06-05 14:00:00	2024-06-05	350.00	9	7832	Синема Парк	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
104	32	6	2024-01-24 16:55:00	2024-01-24	2400.00	9	5812	Якитория	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
105	32	6	2024-02-07 10:30:00	2024-02-07	1100.00	9	5411	Перекрёсток	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
106	32	6	2024-02-20 15:05:00	2024-02-20	3800.00	9	5541	Лукойл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
107	32	6	2024-03-05 09:40:00	2024-03-05	890.00	9	5912	Аптека 36.6	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
108	32	6	2024-03-18 14:15:00	2024-03-18	450.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
109	32	6	2024-04-01 11:50:00	2024-04-01	7200.00	9	5732	М.Видео	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
110	32	6	2024-04-14 17:25:00	2024-04-14	1900.00	9	5411	Вкусвилл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
111	32	6	2024-05-02 09:00:00	2024-05-02	3100.00	9	5812	Кофемания	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
112	32	6	2024-05-16 14:35:00	2024-05-16	1400.00	9	5999	Читай-город	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
113	25	7	2024-01-25 12:20:00	2024-01-25	2900.00	9	5812	Burger King	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
114	25	7	2024-02-08 08:55:00	2024-02-08	4200.00	9	5541	Роснефть	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
115	25	7	2024-02-21 15:30:00	2024-02-21	650.00	9	4111	Автобус	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
116	25	7	2024-03-06 11:05:00	2024-03-06	10500.00	9	5311	Фантастика	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
117	25	7	2024-03-19 17:40:00	2024-03-19	1200.00	9	5411	Пятёрочка	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
118	25	7	2024-04-02 09:15:00	2024-04-02	560.00	9	5912	Ригла	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
119	25	7	2024-04-15 14:50:00	2024-04-15	8900.00	9	5732	DNS	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
120	25	7	2024-05-01 10:25:00	2024-05-01	3400.00	9	5812	KFC	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
121	25	7	2024-05-13 16:00:00	2024-05-13	1700.00	9	5411	Лента	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
122	25	7	2024-05-26 11:35:00	2024-05-26	400.00	9	7832	Киномакс	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
123	47	8	2024-01-26 14:05:00	2024-01-26	1300.00	9	5411	Магнит	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
124	47	8	2024-02-09 10:40:00	2024-02-09	3600.00	9	5541	Лукойл	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
125	47	8	2024-02-22 16:15:00	2024-02-22	780.00	9	5912	Аптека 36.6	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
126	47	8	2024-03-07 09:50:00	2024-03-07	7400.00	9	5311	Красная площадь	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
127	47	8	2024-03-20 15:25:00	2024-03-20	450.00	9	4111	Автобус	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
128	47	8	2024-04-04 11:00:00	2024-04-04	2100.00	9	5812	Чайхона №1	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
129	47	8	2024-04-17 17:35:00	2024-04-17	11000.00	9	5732	Эльдорадо	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
130	47	8	2024-05-03 09:10:00	2024-05-03	1600.00	9	5411	Перекрёсток	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
131	47	8	2024-05-17 14:45:00	2024-05-17	2800.00	9	5812	Якитория	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
132	9	9	2024-01-15 09:30:00	2024-01-15	38000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
133	9	9	2024-01-28 14:00:00	2024-01-28	42000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
134	9	9	2024-02-10 11:45:00	2024-02-10	51000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
135	9	9	2024-02-23 16:20:00	2024-02-23	39000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
136	9	9	2024-03-07 08:55:00	2024-03-07	47000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
137	9	9	2024-03-20 15:30:00	2024-03-20	43000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
138	9	9	2024-04-02 10:05:00	2024-04-02	36000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
139	9	9	2024-04-15 17:40:00	2024-04-15	55000.00	9	7011	Marriott	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
140	39	10	2024-01-02 09:15:00	2024-01-02	1200.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
141	24	11	2024-01-02 11:30:00	2024-01-02	890.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
142	12	12	2024-01-03 13:45:00	2024-01-03	2100.00	9	5411	Пятёрочка	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
143	4	13	2024-01-04 18:20:00	2024-01-04	650.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
144	37	14	2024-01-05 09:00:00	2024-01-05	1450.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
145	14	15	2024-01-06 12:30:00	2024-01-06	3200.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
146	49	16	2024-01-06 14:15:00	2024-01-06	780.00	9	5411	Пятёрочка	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
147	26	17	2024-01-07 10:50:00	2024-01-07	1100.00	9	5411	Пятёрочка	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
148	2	18	2024-01-07 17:25:00	2024-01-07	2400.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
149	8	19	2024-01-08 08:40:00	2024-01-08	560.00	9	5411	Пятёрочка	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
150	46	20	2024-01-09 19:10:00	2024-01-09	1800.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
151	38	21	2024-01-10 11:20:00	2024-01-10	920.00	9	5411	Пятёрочка	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
152	1	22	2024-01-11 15:35:00	2024-01-11	3400.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
153	31	23	2024-01-12 09:55:00	2024-01-12	670.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
154	23	24	2024-01-13 18:00:00	2024-01-13	1550.00	9	5411	Пятёрочка	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
155	28	25	2024-01-14 12:15:00	2024-01-14	2200.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
156	3	26	2024-01-15 10:30:00	2024-01-15	880.00	9	5411	Пятёрочка	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
157	44	27	2024-01-16 16:45:00	2024-01-16	1700.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
158	18	28	2024-01-17 09:20:00	2024-01-17	430.00	9	5411	Пятёрочка	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
159	13	29	2024-01-18 14:50:00	2024-01-18	2600.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
160	43	30	2024-01-19 11:05:00	2024-01-19	1350.00	9	5411	Пятёрочка	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
161	20	31	2024-01-20 17:30:00	2024-01-20	790.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
162	48	32	2024-01-21 10:15:00	2024-01-21	1900.00	9	5411	Пятёрочка	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
163	33	33	2024-01-22 13:40:00	2024-01-22	560.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
164	41	34	2024-01-23 08:55:00	2024-01-23	2800.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
165	39	10	2024-01-02 08:30:00	2024-01-02	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
166	24	11	2024-01-03 07:45:00	2024-01-03	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
167	12	12	2024-01-04 08:15:00	2024-01-04	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
168	4	13	2024-01-05 07:50:00	2024-01-05	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
169	37	14	2024-01-06 08:05:00	2024-01-06	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
170	14	15	2024-01-07 18:30:00	2024-01-07	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
171	49	16	2024-01-08 07:55:00	2024-01-08	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
172	26	17	2024-01-09 18:45:00	2024-01-09	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
173	2	18	2024-01-10 08:20:00	2024-01-10	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
174	8	19	2024-01-11 17:55:00	2024-01-11	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
175	46	20	2024-01-12 08:10:00	2024-01-12	55.00	9	4111	Метро	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
176	38	21	2024-01-13 19:00:00	2024-01-13	55.00	9	4111	Метро	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
177	1	22	2024-01-14 07:40:00	2024-01-14	55.00	9	4111	Метро	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
178	31	23	2024-01-15 18:15:00	2024-01-15	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
179	23	24	2024-01-16 08:35:00	2024-01-16	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
180	28	25	2024-01-17 17:50:00	2024-01-17	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
181	3	26	2024-01-18 08:00:00	2024-01-18	55.00	9	4111	Метро	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
182	44	27	2024-01-19 19:15:00	2024-01-19	55.00	9	4111	Метро	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
183	18	28	2024-01-20 08:25:00	2024-01-20	55.00	9	4111	Метро	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
184	13	29	2024-01-21 18:50:00	2024-01-21	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
185	15	35	2024-01-05 13:00:00	2024-01-05	4500.00	9	5812	Кофемания	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
186	27	36	2024-01-06 20:30:00	2024-01-06	8900.00	9	5812	Якитория	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
187	30	37	2024-01-07 14:15:00	2024-01-07	2300.00	9	5812	Шоколадница	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
188	5	38	2024-01-12 19:45:00	2024-01-12	6700.00	9	5812	Гинза	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
189	35	39	2024-01-13 13:30:00	2024-01-13	1800.00	9	5812	KFC	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
190	50	40	2024-01-14 20:00:00	2024-01-14	3400.00	9	5812	Burger King	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
191	21	41	2024-01-19 14:45:00	2024-01-19	5200.00	9	5812	Чайхона №1	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
192	34	42	2024-01-20 20:15:00	2024-01-20	2100.00	9	5812	Теремок	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
193	45	43	2024-01-25 13:00:00	2024-01-25	7800.00	9	5812	Новиков	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
194	11	44	2024-01-26 19:30:00	2024-01-26	1500.00	9	5812	KFC	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
195	42	45	2024-01-27 14:15:00	2024-01-27	4300.00	9	5812	Кофемания	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
196	10	46	2024-01-28 20:45:00	2024-01-28	9200.00	9	5812	Белуга	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
197	22	47	2024-01-29 13:30:00	2024-01-29	2600.00	9	5812	Шоколадница	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
198	7	48	2024-01-30 19:00:00	2024-01-30	3800.00	9	5812	Якитория	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
199	17	49	2024-01-31 14:45:00	2024-01-31	1200.00	9	5812	Burger King	8	purchase	declined	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
200	15	35	2024-01-08 07:30:00	2024-01-08	3200.00	9	5541	Лукойл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
201	27	36	2024-01-10 16:45:00	2024-01-10	4100.00	9	5541	Роснефть	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
202	30	37	2024-01-15 08:20:00	2024-01-15	2800.00	9	5541	Газпромнефть	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
203	5	38	2024-01-17 17:00:00	2024-01-17	5600.00	9	5541	Лукойл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
204	35	39	2024-01-22 07:45:00	2024-01-22	3900.00	9	5541	Татнефть	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
205	50	40	2024-01-24 16:30:00	2024-01-24	4500.00	9	5541	Роснефть	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
206	21	41	2024-01-26 08:10:00	2024-01-26	2600.00	9	5541	Лукойл	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
207	34	42	2024-01-28 17:45:00	2024-01-28	3300.00	9	5541	Газпромнефть	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
208	45	43	2024-01-30 07:55:00	2024-01-30	4800.00	9	5541	Лукойл	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
209	11	44	2024-01-31 16:15:00	2024-01-31	2100.00	9	5541	Роснефть	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
210	39	10	2024-02-01 10:20:00	2024-02-01	1650.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
211	24	11	2024-02-02 14:35:00	2024-02-02	980.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
212	12	12	2024-02-03 09:50:00	2024-02-03	2300.00	9	5411	Пятёрочка	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
213	4	13	2024-02-05 18:05:00	2024-02-05	750.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
214	37	14	2024-02-07 11:20:00	2024-02-07	1400.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
215	14	15	2024-02-09 15:35:00	2024-02-09	3100.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
216	49	16	2024-02-10 09:50:00	2024-02-10	820.00	9	5411	Пятёрочка	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
217	26	17	2024-02-12 17:05:00	2024-02-12	1250.00	9	5411	Пятёрочка	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
218	2	18	2024-02-14 11:20:00	2024-02-14	2700.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
219	8	19	2024-02-16 15:35:00	2024-02-16	610.00	9	5411	Пятёрочка	10	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
220	46	20	2024-02-17 09:50:00	2024-02-17	1900.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
221	38	21	2024-02-19 18:05:00	2024-02-19	870.00	9	5411	Пятёрочка	4	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
222	1	22	2024-02-21 11:20:00	2024-02-21	3500.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
223	31	23	2024-02-23 15:35:00	2024-02-23	720.00	9	5411	Пятёрочка	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
224	23	24	2024-02-24 09:50:00	2024-02-24	1600.00	9	5411	Пятёрочка	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
225	28	25	2024-02-26 18:05:00	2024-02-26	2200.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
226	3	26	2024-02-27 11:20:00	2024-02-27	940.00	9	5411	Пятёрочка	12	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
227	44	27	2024-02-28 15:35:00	2024-02-28	1750.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
228	18	28	2024-02-29 09:50:00	2024-02-29	480.00	9	5411	Пятёрочка	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
229	13	29	2024-02-29 18:05:00	2024-02-29	2800.00	9	5411	Пятёрочка	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
230	43	30	2024-02-01 07:40:00	2024-02-01	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
231	20	31	2024-02-02 18:55:00	2024-02-02	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
232	48	32	2024-02-05 08:10:00	2024-02-05	55.00	9	4111	Метро	5	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
233	33	33	2024-02-07 19:25:00	2024-02-07	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
234	41	34	2024-02-09 07:40:00	2024-02-09	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
235	15	35	2024-02-12 18:55:00	2024-02-12	55.00	9	4111	Метро	3	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
236	27	36	2024-02-14 08:10:00	2024-02-14	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
237	30	37	2024-02-16 19:25:00	2024-02-16	55.00	9	4111	Метро	11	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
238	5	38	2024-02-19 07:40:00	2024-02-19	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
239	35	39	2024-02-21 18:55:00	2024-02-21	55.00	9	4111	Метро	2	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
240	50	40	2024-02-23 08:10:00	2024-02-23	55.00	9	4111	Метро	8	purchase	success	2026-06-20 11:12:23.821077	2026-06-20 11:12:23.821077	etl_user	f
\.


--
-- TOC entry 5534 (class 0 OID 16624)
-- Dependencies: 251
-- Data for Name: campaign_clients; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.campaign_clients (stg_id, enrollment_dttm, status, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted, campaign_name, client_full_name, card_number_hash) FROM stdin;
1	2024-01-03 10:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на продукты	Иванов Алексей Петрович	86463a6cac402bfda0d381168d46554f
2	2024-01-04 11:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на продукты	Волков Павел Игоревич	f2e35014b9478d853b50c8e599ccf1ac
3	2024-01-16 09:30:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за рестораны	Новикова Екатерина Андреевна	31ce0ae7081e61d01e17f4fbcd0382e0
4	2024-01-17 10:15:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за рестораны	Комарова Елена Дмитриевна	46f11768f7cef80132f6ff8c6843a058
5	2024-02-02 08:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на АЗС	Морозов Игорь Николаевич	2cbf08d6d6c2b31b94d36cb7f3f29275
6	2024-02-03 09:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на АЗС	Попов Сергей Алексеевич	051cd84fb9cc5d41b297f789c97179c8
7	2024-01-02 12:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Миль за путешествия	Кузнецова Ирина Борисовна	2c57c22c3172340709206b69b09af91e
8	2024-01-03 13:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Миль за путешествия	Куликов Денис Игоревич	3ea95560ccca60e8538adc55f99a6edd
9	2024-03-02 10:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на одежду	Федорова Анна Михайловна	a2e92e7ae62a8f49f3cfad77fd73e09e
10	2024-03-03 11:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на одежду	Орлова Юлия Евгеньевна	cccab353dbd4c89f5025a47b2c182284
11	2024-02-16 09:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за электронику	Соколов Артём Владимирович	c2335bc3483ee04fa170be79301f1766
12	2024-02-17 10:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за электронику	Михайлов Роман Дмитриевич	1a655a3c9acf92ba96c3cbd01056a6e4
13	2024-01-02 08:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк для студентов	Логинов Илья Станиславович	fe60d9deb07c243a2ebbe1c4f0eb8fa4
14	2024-01-03 09:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк для студентов	Беляев Тимур Александрович	4c381c194283ed3fdda088402a7d1e22
15	2024-01-02 10:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы для пенсионеров	Белова Тамара Ивановна	ad21653fb3d470a799eba9968537a34b
16	2024-01-03 11:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы для пенсионеров	Громова Надежда Петровна	c1262a319362dc7e46c2999968eb253a
17	2024-03-02 09:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Платинум привилегии	Крылов Николай Федорович	08d29326c1e2fed2fd468254df8f1f52
18	2024-03-03 10:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Платинум привилегии	Медведева Татьяна Сергеевна	8bd40b59e1a7bffb3a661ae5809f05c3
19	2024-02-02 11:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк мультикарта	Зайцева Мария Олеговна	d17176b613a57a9f6cbb35bc1638b11f
20	2024-02-03 12:00:00	active	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк мультикарта	Сергеева Дарья Николаевна	63a60d5282c045c2759f59f31b91ecf3
\.


--
-- TOC entry 5536 (class 0 OID 16635)
-- Dependencies: 253
-- Data for Name: campaign_rewards; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.campaign_rewards (stg_id, reward_amount, reward_dt, reward_status, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted, campaign_name, client_full_name, card_number_hash, transaction_dttm) FROM stdin;
1	45.00	2024-01-06	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на продукты	Иванов Алексей Петрович	86463a6cac402bfda0d381168d46554f	2024-01-05 10:23:00
2	21.00	2024-01-12	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на продукты	Волков Павел Игоревич	f2e35014b9478d853b50c8e599ccf1ac	2024-01-11 16:45:00
3	22.50	2024-01-09	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за рестораны	Новикова Екатерина Андреевна	31ce0ae7081e61d01e17f4fbcd0382e0	2024-01-08 14:30:00
4	140.00	2024-01-31	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за рестораны	Комарова Елена Дмитриевна	46f11768f7cef80132f6ff8c6843a058	2024-01-30 11:00:00
5	84.00	2024-01-10	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на АЗС	Морозов Игорь Николаевич	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-01-09 18:00:00
6	136.00	2024-01-16	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на АЗС	Попов Сергей Алексеевич	051cd84fb9cc5d41b297f789c97179c8	2024-01-15 10:45:00
7	840.00	2024-01-17	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Миль за путешествия	Кузнецова Ирина Борисовна	2c57c22c3172340709206b69b09af91e	2024-01-16 15:30:00
8	4690.00	2024-02-04	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Миль за путешествия	Куликов Денис Игоревич	3ea95560ccca60e8538adc55f99a6edd	2024-02-03 12:20:00
9	750.00	2024-03-02	pending	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на одежду	Федорова Анна Михайловна	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-01-10 11:20:00
10	49.00	2024-03-03	pending	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк на одежду	Орлова Юлия Евгеньевна	cccab353dbd4c89f5025a47b2c182284	2024-01-20 14:50:00
11	2700.00	2024-02-17	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за электронику	Соколов Артём Владимирович	c2335bc3483ee04fa170be79301f1766	2024-01-13 20:15:00
12	53.40	2024-02-18	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы за электронику	Михайлов Роман Дмитриевич	1a655a3c9acf92ba96c3cbd01056a6e4	2024-01-17 09:00:00
13	21.50	2024-02-02	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк для студентов	Логинов Илья Станиславович	fe60d9deb07c243a2ebbe1c4f0eb8fa4	2024-02-01 16:30:00
14	31.00	2024-02-18	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк для студентов	Беляев Тимур Александрович	4c381c194283ed3fdda088402a7d1e22	2024-02-17 15:50:00
15	22.00	2024-01-23	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы для пенсионеров	Белова Тамара Ивановна	ad21653fb3d470a799eba9968537a34b	2024-01-22 16:00:00
16	44.00	2024-01-27	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Бонусы для пенсионеров	Громова Надежда Петровна	c1262a319362dc7e46c2999968eb253a	2024-01-26 10:05:00
17	2800.00	2024-03-03	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Платинум привилегии	Крылов Николай Федорович	08d29326c1e2fed2fd468254df8f1f52	2024-01-23 19:25:00
18	1350.00	2024-03-04	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Платинум привилегии	Медведева Татьяна Сергеевна	8bd40b59e1a7bffb3a661ae5809f05c3	2024-02-20 08:05:00
19	196.00	2024-02-03	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк мультикарта	Зайцева Мария Олеговна	d17176b613a57a9f6cbb35bc1638b11f	2024-01-12 08:30:00
20	136.50	2024-02-07	paid	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f	Кэшбэк мультикарта	Сергеева Дарья Николаевна	63a60d5282c045c2759f59f31b91ecf3	2024-02-06 14:40:00
\.


--
-- TOC entry 5532 (class 0 OID 16611)
-- Dependencies: 249
-- Data for Name: campaigns; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.campaigns (stg_id, campaign_name, campaign_type, start_dt, end_dt, target_segment, product_code, reward_rate, budget, currency_code, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	Кэшбэк на продукты	cashback	2024-01-01	2024-03-31	mass	DEBIT_SALARY	3.00	500000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
2	Бонусы за рестораны	bonus	2024-01-15	2024-04-15	premium	DEBIT_GOLD	5.00	300000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
3	Кэшбэк на АЗС	cashback	2024-02-01	2024-05-31	mass	DEBIT_SILVER	4.00	400000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
4	Миль за путешествия	miles	2024-01-01	2024-06-30	premium	CREDIT_TRAVEL	7.00	1000000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
5	Кэшбэк на одежду	cashback	2024-03-01	2024-05-31	mass	DEBIT_PREMIUM	5.00	600000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
6	Бонусы за электронику	bonus	2024-02-15	2024-04-30	premium	CREDIT_GOLD	6.00	800000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
7	Кэшбэк для студентов	cashback	2024-01-01	2024-12-31	student	DEBIT_STUDENT	5.00	200000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
8	Бонусы для пенсионеров	bonus	2024-01-01	2024-12-31	pensioner	DEBIT_PENSIONER	4.00	150000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
9	Платинум привилегии	cashback	2024-03-01	2024-06-30	vip	CREDIT_PLATINUM	10.00	2000000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
10	Кэшбэк мультикарта	cashback	2024-02-01	2024-07-31	mass	MULTI_CARD	3.50	350000.00	RUB	2026-06-17 21:53:22.53347	campaign_system	t	2026-06-17 21:53:22.53347	etl_user	f
\.


--
-- TOC entry 5585 (class 0 OID 17276)
-- Dependencies: 302
-- Data for Name: cards; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.cards (stg_id, client_full_name, product_code, card_number_hash, card_status, open_dt, close_dt, expiry_dt, credit_limit, currency_code, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	Иванов Алексей Петрович	DEBIT_SALARY	86463a6cac402bfda0d381168d46554f	active	2020-01-15	\N	2025-01-15	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
2	Смирнова Ольга Викторовна	DEBIT_SILVER	b77db32220b56a5015adc16bcb974ff8	active	2021-03-22	\N	2026-03-22	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
3	Козлов Дмитрий Сергеевич	CREDIT_GOLD	b7ffd93b27884ecb1026947e7514ed3d	active	2019-07-10	\N	2024-07-10	300000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
4	Новикова Екатерина Андреевна	DEBIT_GOLD	31ce0ae7081e61d01e17f4fbcd0382e0	active	2022-05-18	\N	2027-05-18	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
5	Морозов Игорь Николаевич	CREDIT_CLASSIC	2cbf08d6d6c2b31b94d36cb7f3f29275	active	2020-09-27	\N	2025-09-27	100000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
6	Федорова Анна Михайловна	DEBIT_PREMIUM	a2e92e7ae62a8f49f3cfad77fd73e09e	active	2021-01-14	\N	2026-01-14	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
7	Волков Павел Игоревич	DEBIT_SALARY	f2e35014b9478d853b50c8e599ccf1ac	active	2018-06-30	\N	2023-06-30	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
8	Зайцева Мария Олеговна	MULTI_CARD	d17176b613a57a9f6cbb35bc1638b11f	active	2022-12-09	\N	2027-12-09	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
9	Соколов Артём Владимирович	CREDIT_PLATINUM	c2335bc3483ee04fa170be79301f1766	active	2020-04-21	\N	2025-04-21	1000000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
10	Лебедева Наталья Юрьевна	DEBIT_SILVER	13c76899fb85e6d585ac7dca0f1592e4	active	2021-08-05	\N	2026-08-05	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
11	Попов Сергей Алексеевич	DEBIT_SALARY	051cd84fb9cc5d41b297f789c97179c8	active	2019-02-17	\N	2024-02-17	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
12	Кузнецова Ирина Борисовна	CREDIT_TRAVEL	2c57c22c3172340709206b69b09af91e	active	2022-10-25	\N	2027-10-25	500000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
13	Михайлов Роман Дмитриевич	DEBIT_GOLD	1a655a3c9acf92ba96c3cbd01056a6e4	active	2021-03-08	\N	2026-03-08	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
14	Петрова Светлана Александровна	DEBIT_PREMIUM	1019ec9d35eccc7f727164f02827ae71	active	2020-07-19	\N	2025-07-19	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
15	Захаров Андрей Олегович	CREDIT_GOLD	74ba39b275456d6c87e5ad2ba7ba0d9c	active	2019-11-12	\N	2024-11-12	300000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
16	Орлова Юлия Евгеньевна	MULTI_CARD	cccab353dbd4c89f5025a47b2c182284	active	2022-04-03	\N	2027-04-03	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
17	Степанов Виктор Павлович	DEBIT_SALARY	2e37bca84257c2f1bb6e2ec31ed3129e	blocked	2017-09-16	\N	2022-09-16	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
18	Белова Тамара Ивановна	DEBIT_PENSIONER	ad21653fb3d470a799eba9968537a34b	active	2021-12-28	\N	2026-12-28	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
19	Крылов Николай Федорович	CREDIT_PLATINUM	08d29326c1e2fed2fd468254df8f1f52	active	2020-06-07	\N	2025-06-07	1000000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
20	Антонова Валерия Сергеевна	DEBIT_STUDENT	1118c8a912757d2b1069a2ad974dfcce	active	2022-01-23	\N	2027-01-23	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
21	Тихонов Максим Юрьевич	DEBIT_SILVER	2fb94a26ea921b25e3cfaf83a7d23f86	active	2021-05-11	\N	2026-05-11	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
22	Громова Надежда Петровна	DEBIT_PENSIONER	c1262a319362dc7e46c2999968eb253a	active	2020-08-14	\N	2025-08-14	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
23	Ефимов Константин Аркадьевич	DEBIT_PREMIUM	c14c8ff146dc25cf2cff54334f7417a8	active	2019-03-29	\N	2024-03-29	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
24	Никитина Галина Романовна	DEBIT_SALARY	1b4dfbdd4d8bba68eec217b639d070ca	active	2022-10-06	\N	2027-10-06	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
25	Борисов Евгений Анатольевич	CREDIT_CLASSIC	4db4802622eaf31ea48bfcbfeedb270c	active	2021-02-18	\N	2026-02-18	100000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
26	Комарова Елена Дмитриевна	DEBIT_GOLD	46f11768f7cef80132f6ff8c6843a058	active	2020-07-31	\N	2025-07-31	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
27	Логинов Илья Станиславович	DEBIT_STUDENT	fe60d9deb07c243a2ebbe1c4f0eb8fa4	active	2022-04-15	\N	2027-04-15	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
28	Фролова Оксана Владимировна	DEBIT_SALARY	d9cb5930f320f334fa0691efc85e845f	active	2019-11-20	\N	2024-11-20	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
29	Куликов Денис Игоревич	CREDIT_TRAVEL	3ea95560ccca60e8538adc55f99a6edd	active	2021-06-04	\N	2026-06-04	500000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
30	Воробьева Алина Константиновна	DEBIT_SILVER	44e09a74c39ed9d9b80f2bedd5181d32	active	2022-09-13	\N	2027-09-13	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
31	Макаров Владислав Олегович	DEBIT_SALARY	f26838f490873e4ffa6c10000f29372d	blocked	2018-01-27	\N	2023-01-27	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
32	Сергеева Дарья Николаевна	MULTI_CARD	63a60d5282c045c2759f59f31b91ecf3	active	2021-05-09	\N	2026-05-09	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
33	Тарасов Георгий Михайлович	DEBIT_PREMIUM	40556da66f53c530af922e2a5771740d	active	2020-08-22	\N	2025-08-22	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
34	Панова Кристина Евгеньевна	DEBIT_SILVER	ded0c48d679491231b7a90f78783a04b	active	2022-03-16	\N	2027-03-16	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
35	Королёв Артур Васильевич	CREDIT_GOLD	f0d7fb9fb2fe112c0321d9e53120ff94	active	2019-12-01	\N	2024-12-01	300000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
36	Гусева Людмила Аркадьевна	DEBIT_SALARY	bd54775ae3dff3c32650a4d55ef687f7	active	2021-06-18	\N	2026-06-18	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
37	Ильин Станислав Романович	CREDIT_CLASSIC	6dc774b4932a7d7bb6d38f976f16ddbb	active	2020-02-07	\N	2025-02-07	100000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
38	Щербакова Вероника Павловна	DEBIT_GOLD	455febaf1a66ab9ada96bbb04c66a325	active	2022-09-24	\N	2027-09-24	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
39	Осипов Леонид Борисович	DEBIT_PREMIUM	34f7afa3384d9e9362c7a1f81dba1d74	active	2021-04-12	\N	2026-04-12	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
40	Матвеева Полина Игоревна	MULTI_CARD	d7071917a1bdad1dcc649d7c6f6171cb	active	2022-11-05	\N	2027-11-05	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
41	Громов Василий Петрович	DEBIT_SALARY	2d6bbb7f244cbec701170225aa044d23	active	2019-07-08	\N	2024-07-08	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
42	Кириллова Жанна Олеговна	DEBIT_PREMIUM	4dbf0d5b7af1473e4510e2703ae8c7e5	active	2021-01-19	\N	2026-01-19	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
43	Беляев Тимур Александрович	DEBIT_STUDENT	4c381c194283ed3fdda088402a7d1e22	active	2022-08-30	\N	2027-08-30	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
44	Савельева Марина Юрьевна	CREDIT_TRAVEL	853edf9fd145780210f8aeb2501495e0	active	2020-03-23	\N	2025-03-23	500000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
45	Назаров Олег Викторович	DEBIT_SILVER	f6f59ab82bae5b8acaad2fe7489888a3	active	2021-10-14	\N	2026-10-14	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
46	Медведева Татьяна Сергеевна	CREDIT_PLATINUM	8bd40b59e1a7bffb3a661ae5809f05c3	active	2019-05-27	\N	2024-05-27	1000000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
47	Калинин Руслан Дмитриевич	DEBIT_SALARY	b8976f5ac7c42d377f16f782bdf29377	blocked	2017-12-16	\N	2022-12-16	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
48	Зубова Анастасия Николаевна	DEBIT_GOLD	cc2739e03a55a2baf5079f4ab0f7b314	active	2022-04-08	\N	2027-04-08	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
49	Герасимов Антон Леонидович	CREDIT_GOLD	f2d81545d56b9a97be8cd346f2f069b3	active	2020-09-21	\N	2025-09-21	300000	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
50	Соловьева Регина Аркадьевна	DEBIT_PREMIUM	dfe5c842ed015ea49d664ca6a33ac7d2	active	2021-02-14	\N	2026-02-14	\N	RUB	2026-06-14 16:32:55.953487	card_system	t	2026-06-14 16:32:55.953487	etl_user	f
\.


--
-- TOC entry 5530 (class 0 OID 16572)
-- Dependencies: 247
-- Data for Name: clients; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.clients (stg_id, full_name, birth_dt, gender, city_raw, segment, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	Иванов Алексей Петрович	1985-03-15	M	Москва	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
2	Смирнова Ольга Викторовна	1990-07-22	F	Санкт-Петербург	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
3	Козлов Дмитрий Сергеевич	1978-11-03	M	Новосибирск	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
4	Новикова Екатерина Андреевна	1995-05-18	F	Екатеринбург	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
5	Морозов Игорь Николаевич	1982-09-27	M	Казань	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
6	Федорова Анна Михайловна	1993-01-14	F	Москва	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
7	Волков Павел Игоревич	1988-06-30	M	Нижний Новгород	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
8	Зайцева Мария Олеговна	1997-12-09	F	Краснодар	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
9	Соколов Артём Владимирович	1975-04-21	M	Самара	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
10	Лебедева Наталья Юрьевна	1991-08-05	F	Ростов-на-Дону	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
11	Попов Сергей Алексеевич	1983-02-17	M	Уфа	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
12	Кузнецова Ирина Борисовна	1969-10-25	F	Воронеж	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
13	Михайлов Роман Дмитриевич	1994-03-08	M	Пермь	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
14	Петрова Светлана Александровна	1987-07-19	F	Москва	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
15	Захаров Андрей Олегович	1979-11-12	M	Санкт-Петербург	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
16	Орлова Юлия Евгеньевна	1996-04-03	F	Новосибирск	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
17	Степанов Виктор Павлович	1971-09-16	M	Екатеринбург	mass	false	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
18	Белова Тамара Ивановна	1958-12-28	F	Казань	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
19	Крылов Николай Федорович	1986-06-07	M	Нижний Новгород	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
20	Антонова Валерия Сергеевна	1999-01-23	F	Краснодар	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
21	Тихонов Максим Юрьевич	1984-05-11	M	Самара	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
22	Громова Надежда Петровна	1962-08-14	F	Ростов-на-Дону	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
23	Ефимов Константин Аркадьевич	1977-03-29	M	Уфа	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
24	Никитина Галина Романовна	1989-10-06	F	Воронеж	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
25	Борисов Евгений Анатольевич	1992-02-18	M	Пермь	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
26	Комарова Елена Дмитриевна	1980-07-31	F	Москва	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
27	Логинов Илья Станиславович	1998-04-15	M	Санкт-Петербург	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
28	Фролова Оксана Владимировна	1973-11-20	F	Новосибирск	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
29	Куликов Денис Игоревич	1991-06-04	M	Екатеринбург	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
30	Воробьева Алина Константиновна	2000-09-13	F	Казань	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
31	Макаров Владислав Олегович	1976-01-27	M	Нижний Новгород	mass	false	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
32	Сергеева Дарья Николаевна	1994-05-09	F	Краснодар	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
33	Тарасов Георгий Михайлович	1968-08-22	M	Самара	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
34	Панова Кристина Евгеньевна	1997-03-16	F	Ростов-на-Дону	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
35	Королёв Артур Васильевич	1985-12-01	M	Уфа	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
36	Гусева Людмила Аркадьевна	1960-06-18	F	Воронеж	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
37	Ильин Станислав Романович	1989-02-07	M	Пермь	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
38	Щербакова Вероника Павловна	1993-09-24	F	Москва	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
39	Осипов Леонид Борисович	1981-04-12	M	Санкт-Петербург	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
40	Матвеева Полина Игоревна	1996-11-05	F	Новосибирск	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
41	Громов Василий Петрович	1974-07-08	M	Екатеринбург	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
42	Кириллова Жанна Олеговна	1987-01-19	F	Казань	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
43	Беляев Тимур Александрович	1999-08-30	M	Нижний Новгород	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
44	Савельева Марина Юрьевна	1978-03-23	F	Краснодар	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
45	Назаров Олег Викторович	1983-10-14	M	Самара	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
46	Медведева Татьяна Сергеевна	1991-05-27	F	Ростов-на-Дону	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
47	Калинин Руслан Дмитриевич	1986-12-16	M	Уфа	mass	false	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
48	Зубова Анастасия Николаевна	1995-04-08	F	Воронеж	mass	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
49	Герасимов Антон Леонидович	1970-09-21	M	Пермь	premium	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
50	Соловьева Регина Аркадьевна	1988-02-14	F	Москва	vip	true	2026-06-11 18:37:27.137723	crm_system	t	2026-06-11 18:37:27.137723	etl_user	f
\.


--
-- TOC entry 5528 (class 0 OID 16559)
-- Dependencies: 245
-- Data for Name: dict_card_products; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_card_products (stg_id, product_code, product_name, product_category, product_tier, target_audience, min_age, max_age, annual_fee, cashback_base_rate, credit_limit_max, is_active, valid_from_dt, valid_to_dt, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	DEBIT_CHILD	Детская карта	debit	standard	Дети 6–14 лет	6	14	0	1.0	\N	true	2018-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
2	DEBIT_STUDENT	Студенческая карта	debit	standard	Студенты 14–25 лет	14	25	0	2.0	\N	true	2018-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
3	DEBIT_SALARY	Зарплатная карта	debit	standard	Зарплатные клиенты	18	\N	0	1.5	\N	true	2015-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
4	DEBIT_SILVER	Серебряная карта	debit	silver	Массовый сегмент	18	\N	599	2.0	\N	true	2017-06-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
5	DEBIT_GOLD	Золотая дебетовая карта	debit	gold	Массовый сегмент	18	\N	3000	3.0	\N	true	2016-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
6	DEBIT_PREMIUM	Премиальная карта	debit	premium	VIP-клиенты	21	\N	15000	5.0	\N	true	2019-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
7	CREDIT_CLASSIC	Классическая кредитная	credit	standard	Масс-сегмент	21	\N	1200	1.0	100000	true	2015-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
8	CREDIT_GOLD	Золотая кредитная карта	credit	gold	Масс-сегмент	21	\N	3500	3.0	300000	true	2016-06-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
9	CREDIT_PLATINUM	Платиновая кредитная карта	credit	platinum	Premium-сегмент	21	\N	10000	5.0	1000000	true	2018-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
10	CREDIT_TRAVEL	Тревел-карта	credit	gold	Путешественники	21	\N	4900	3.0	500000	true	2020-03-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
11	MULTI_CARD	Мультикарта	debit	standard	Все клиенты	18	\N	0	2.0	\N	true	2021-01-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
12	PREPAID_VIRTUAL	Виртуальная предоплаченная	prepaid	standard	Онлайн-покупки	14	\N	0	0.0	\N	true	2022-06-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
13	DEBIT_PENSIONER	Пенсионная карта	debit	standard	Пенсионеры от 55 лет	55	\N	0	3.0	\N	true	2019-09-01	\N	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
14	CREDIT_CLASSIC_V1	Классическая кредитная (old)	credit	standard	Масс-сегмент (архив)	21	\N	900	0.5	50000	false	2010-01-01	2014-12-31	2026-06-11 18:37:27.106393	product_system	t	2026-06-11 18:37:27.106393	etl_user	f
\.


--
-- TOC entry 5518 (class 0 OID 16498)
-- Dependencies: 235
-- Data for Name: dict_cities; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_cities (stg_id, city_name, city_name_en, city_type, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	Москва	Moscow	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
2	Санкт-Петербург	Saint Petersburg	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
3	Новосибирск	Novosibirsk	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
4	Екатеринбург	Yekaterinburg	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
5	Казань	Kazan	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
6	Нижний Новгород	Nizhny Novgorod	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
7	Краснодар	Krasnodar	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
8	Самара	Samara	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
9	Ростов-на-Дону	Rostov-on-Don	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
10	Уфа	Ufa	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
11	Воронеж	Voronezh	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
12	Пермь	Perm	city	true	2026-06-11 18:37:27.033042	hr_system	t	2026-06-11 18:37:27.033042	etl_user	f
\.


--
-- TOC entry 5520 (class 0 OID 16511)
-- Dependencies: 237
-- Data for Name: dict_currencies; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_currencies (stg_id, currency_code, currency_name_ru, currency_symbol, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	RUB	Российский рубль	₽	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
2	USD	Доллар США	$	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
3	EUR	Евро	€	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
4	CNY	Китайский юань	¥	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
5	GBP	Британский фунт	£	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
6	CHF	Швейцарский франк	₣	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
7	TRY	Турецкая лира	₺	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
8	AED	Дирхам ОАЭ	د.إ	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
9	KZT	Казахстанский тенге	₸	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
10	BYN	Белорусский рубль	Br	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
11	JPY	Японская иена	¥	false	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
12	AMD	Армянский драм	֏	true	2026-06-11 18:37:27.053198	cbr_feed	t	2026-06-11 18:37:27.053198	etl_user	f
\.


--
-- TOC entry 5524 (class 0 OID 16533)
-- Dependencies: 241
-- Data for Name: dict_departments; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_departments (stg_id, src_department_id, src_parent_dept_id, src_city_name, department_name, department_code, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	1	\N	Москва	Головной офис	HQ	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
2	2	1	Москва	Департамент розничного бизнеса	RETAIL	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
3	3	1	Москва	Департамент маркетинга	MARKETING	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
4	4	1	Москва	Департамент информационных систем	IT	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
5	5	1	Москва	Департамент рисков	RISK	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
6	6	2	Москва	Отдел карточных продуктов	CARDS	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
7	7	3	Москва	Отдел CRM и акций	CRM	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
8	8	4	Москва	Отдел аналитики данных	ANALYTICS	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
9	9	4	Москва	Отдел разработки	DEV	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
10	10	1	Санкт-Петербург	Филиал Санкт-Петербург	BRANCH_SPB	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
11	11	1	Новосибирск	Филиал Новосибирск	BRANCH_NSK	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
12	12	1	Екатеринбург	Филиал Екатеринбург	BRANCH_EKB	true	2026-06-11 18:37:27.074328	hr_system	t	2026-06-11 18:37:27.074328	etl_user	f
\.


--
-- TOC entry 5526 (class 0 OID 16546)
-- Dependencies: 243
-- Data for Name: dict_employees; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_employees (stg_id, src_department_id, src_manager_id, src_city_name, full_name, "position", role, email, hire_dt, fire_dt, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	1	\N	Москва	Иванов Алексей Петрович	Председатель правления	admin	ivanov@bank.ru	2010-03-01	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
2	2	1	Москва	Смирнова Ольга Викторовна	Директор розничного бизнеса	manager	smirnova@bank.ru	2013-06-15	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
3	3	1	Москва	Козлов Дмитрий Сергеевич	Директор по маркетингу	manager	kozlov@bank.ru	2015-01-10	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
4	4	1	Москва	Новикова Екатерина Андреевна	ИТ-директор	admin	novikova@bank.ru	2014-09-01	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
5	6	2	Москва	Морозов Игорь Николаевич	Руководитель отдела карт	manager	morozov@bank.ru	2017-04-20	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
6	7	3	Москва	Федорова Анна Михайловна	Руководитель CRM	manager	fedorova@bank.ru	2018-11-05	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
7	8	4	Москва	Волков Павел Игоревич	Старший аналитик данных	analyst	volkov@bank.ru	2019-02-14	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
8	8	7	Москва	Зайцева Мария Олеговна	Аналитик данных	analyst	zaitseva@bank.ru	2021-07-01	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
9	9	4	Москва	Соколов Артём Владимирович	Разработчик БД	developer	sokolov@bank.ru	2020-03-15	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
10	10	1	Санкт-Петербург	Лебедева Наталья Юрьевна	Директор филиала СПб	manager	lebedeva@bank.ru	2016-08-22	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
11	11	1	Новосибирск	Попов Сергей Алексеевич	Директор филиала НСК	manager	popov@bank.ru	2018-05-30	\N	true	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
12	5	1	Москва	Кузнецова Ирина Борисовна	Директор по рискам	manager	kuznetsova@bank.ru	2012-10-17	2024-12-31	false	2026-06-11 18:37:27.088727	hr_system	t	2026-06-11 18:37:27.088727	etl_user	f
\.


--
-- TOC entry 5522 (class 0 OID 16522)
-- Dependencies: 239
-- Data for Name: dict_mcc; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.dict_mcc (stg_id, mcc_code, mcc_name, mcc_group, is_active, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	5411	Продуктовые магазины и супермаркеты	food	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
2	5812	Рестораны и кафе	food	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
3	5541	Автозаправочные станции	auto	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
4	5912	Аптеки	health	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
5	5311	Универмаги	retail	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
6	5732	Электроника и бытовая техника	retail	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
7	4111	Городской транспорт	transport	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
8	4112	Железнодорожный транспорт	transport	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
9	3000	Авиабилеты	travel	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
10	7011	Гостиницы и отели	travel	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
11	7832	Кинотеатры	entertainment	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
12	5999	Прочие магазины	other	true	2026-06-11 18:37:27.063224	mcc_registry	t	2026-06-11 18:37:27.063224	etl_user	f
\.


--
-- TOC entry 5587 (class 0 OID 17395)
-- Dependencies: 304
-- Data for Name: transactions; Type: TABLE DATA; Schema: stg; Owner: postgres
--

COPY stg.transactions (stg_id, card_number_hash, transaction_dttm, amount, currency_code, mcc_code, merchant_name, city_raw, transaction_type, status, load_dttm, src_name, is_processed, created_dttm, created_by, is_deleted) FROM stdin;
1	86463a6cac402bfda0d381168d46554f	2024-01-05 10:23:00	1500.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
2	b77db32220b56a5015adc16bcb974ff8	2024-01-06 12:45:00	3200.00	RUB	5812	Кофемания	Санкт-Петербург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
3	b7ffd93b27884ecb1026947e7514ed3d	2024-01-07 09:15:00	8500.00	RUB	5651	Zara	Новосибирск	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
4	31ce0ae7081e61d01e17f4fbcd0382e0	2024-01-08 14:30:00	450.00	RUB	4111	Метро	Екатеринбург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
5	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-01-09 18:00:00	2100.00	RUB	5912	Аптека 36.6	Казань	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
6	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-01-10 11:20:00	15000.00	RUB	5732	DNS	Москва	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
7	f2e35014b9478d853b50c8e599ccf1ac	2024-01-11 16:45:00	700.00	RUB	5411	Магнит	Нижний Новгород	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
8	d17176b613a57a9f6cbb35bc1638b11f	2024-01-12 08:30:00	5600.00	RUB	5812	Burger King	Краснодар	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
9	c2335bc3483ee04fa170be79301f1766	2024-01-13 20:15:00	45000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
10	13c76899fb85e6d585ac7dca0f1592e4	2024-01-14 13:00:00	1200.00	RUB	5411	Лента	Ростов-на-Дону	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
11	051cd84fb9cc5d41b297f789c97179c8	2024-01-15 10:45:00	3400.00	RUB	5541	Лукойл	Уфа	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
12	2c57c22c3172340709206b69b09af91e	2024-01-16 15:30:00	12000.00	RUB	4722	Туттиairlines	Воронеж	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
13	1a655a3c9acf92ba96c3cbd01056a6e4	2024-01-17 09:00:00	890.00	RUB	5999	Fix Price	Пермь	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
14	1019ec9d35eccc7f727164f02827ae71	2024-01-18 17:20:00	6700.00	RUB	5651	H&M	Москва	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
15	74ba39b275456d6c87e5ad2ba7ba0d9c	2024-01-19 12:10:00	2300.00	RUB	5812	Шоколадница	Санкт-Петербург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
16	cccab353dbd4c89f5025a47b2c182284	2024-01-20 14:50:00	980.00	RUB	5411	Ашан	Новосибирск	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
17	2e37bca84257c2f1bb6e2ec31ed3129e	2024-01-21 11:35:00	1800.00	RUB	5912	Ригла	Екатеринбург	purchase	declined	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
18	ad21653fb3d470a799eba9968537a34b	2024-01-22 16:00:00	550.00	RUB	4111	Автобус	Казань	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
19	08d29326c1e2fed2fd468254df8f1f52	2024-01-23 19:25:00	28000.00	RUB	5732	М.Видео	Нижний Новгород	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
20	1118c8a912757d2b1069a2ad974dfcce	2024-01-24 08:15:00	760.00	RUB	5411	Дикси	Краснодар	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
21	2fb94a26ea921b25e3cfaf83a7d23f86	2024-01-25 13:40:00	4200.00	RUB	5812	KFC	Самара	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
22	c1262a319362dc7e46c2999968eb253a	2024-01-26 10:05:00	1100.00	RUB	5541	Газпромнефть	Ростов-на-Дону	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
23	c14c8ff146dc25cf2cff54334f7417a8	2024-01-27 15:55:00	32000.00	RUB	7011	Hilton	Уфа	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
24	1b4dfbdd4d8bba68eec217b639d070ca	2024-01-28 09:30:00	1650.00	RUB	5999	Читай-город	Воронеж	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
25	4db4802622eaf31ea48bfcbfeedb270c	2024-01-29 14:15:00	9800.00	RUB	5651	Adidas	Пермь	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
26	46f11768f7cef80132f6ff8c6843a058	2024-01-30 11:00:00	2800.00	RUB	5812	Якитория	Москва	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
27	fe60d9deb07c243a2ebbe1c4f0eb8fa4	2024-02-01 16:30:00	430.00	RUB	4111	Трамвай	Санкт-Петербург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
28	d9cb5930f320f334fa0691efc85e845f	2024-02-02 08:45:00	5100.00	RUB	5541	Роснефть	Новосибирск	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
29	3ea95560ccca60e8538adc55f99a6edd	2024-02-03 12:20:00	67000.00	RUB	4722	Аэрофлот	Екатеринбург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
30	44e09a74c39ed9d9b80f2bedd5181d32	2024-02-04 17:10:00	1350.00	RUB	5411	Перекрёсток	Казань	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
31	f26838f490873e4ffa6c10000f29372d	2024-02-05 10:55:00	780.00	RUB	5912	Планета здоровья	Нижний Новгород	purchase	declined	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
32	63a60d5282c045c2759f59f31b91ecf3	2024-02-06 14:40:00	3900.00	RUB	5812	Теремок	Краснодар	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
33	40556da66f53c530af922e2a5771740d	2024-02-07 09:25:00	18500.00	RUB	5732	Эльдорадо	Самара	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
34	ded0c48d679491231b7a90f78783a04b	2024-02-08 15:15:00	2200.00	RUB	5999	Sunlight	Ростов-на-Дону	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
35	f0d7fb9fb2fe112c0321d9e53120ff94	2024-02-09 11:50:00	7600.00	RUB	5651	Nike	Уфа	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
36	bd54775ae3dff3c32650a4d55ef687f7	2024-02-10 16:35:00	1900.00	RUB	5411	Вкусвилл	Воронеж	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
37	6dc774b4932a7d7bb6d38f976f16ddbb	2024-02-11 08:20:00	4500.00	RUB	5812	Макдоналдс	Пермь	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
38	455febaf1a66ab9ada96bbb04c66a325	2024-02-12 13:05:00	22000.00	RUB	5732	Apple Store	Москва	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
39	34f7afa3384d9e9362c7a1f81dba1d74	2024-02-13 17:50:00	3100.00	RUB	5541	BP	Санкт-Петербург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
40	d7071917a1bdad1dcc649d7c6f6171cb	2024-02-14 10:35:00	850.00	RUB	5411	Красное&Белое	Новосибирск	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
41	2d6bbb7f244cbec701170225aa044d23	2024-02-15 14:20:00	5800.00	RUB	5812	Ginza	Екатеринбург	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
42	4dbf0d5b7af1473e4510e2703ae8c7e5	2024-02-16 09:05:00	41000.00	RUB	7011	Radisson	Казань	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
43	4c381c194283ed3fdda088402a7d1e22	2024-02-17 15:50:00	620.00	RUB	4111	Метро	Нижний Новгород	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
44	853edf9fd145780210f8aeb2501495e0	2024-02-18 11:35:00	89000.00	RUB	4722	S7 Airlines	Краснодар	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
45	f6f59ab82bae5b8acaad2fe7489888a3	2024-02-19 16:20:00	1750.00	RUB	5999	Леруа Мерлен	Самара	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
46	8bd40b59e1a7bffb3a661ae5809f05c3	2024-02-20 08:05:00	13500.00	RUB	5651	Massimo Dutti	Ростов-на-Дону	purchase	success	2026-06-16 18:15:36.072943	tx_system	t	2026-06-16 18:15:36.072943	etl_user	f
47	86463a6cac402bfda0d381168d46554f	2024-01-05 10:23:00	1500.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
48	86463a6cac402bfda0d381168d46554f	2024-01-18 09:15:00	3200.00	RUB	5812	Кофемания	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
49	86463a6cac402bfda0d381168d46554f	2024-01-25 14:40:00	450.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
50	86463a6cac402bfda0d381168d46554f	2024-02-03 11:20:00	8700.00	RUB	5732	DNS	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
51	86463a6cac402bfda0d381168d46554f	2024-02-14 18:30:00	2100.00	RUB	5912	Аптека 36.6	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
52	86463a6cac402bfda0d381168d46554f	2024-02-28 13:05:00	980.00	RUB	5411	Магнит	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
53	86463a6cac402bfda0d381168d46554f	2024-03-07 09:50:00	15000.00	RUB	5311	ЦУМ	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
54	86463a6cac402bfda0d381168d46554f	2024-03-15 16:25:00	560.00	RUB	5812	Шоколадница	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
55	86463a6cac402bfda0d381168d46554f	2024-03-22 12:10:00	1200.00	RUB	5411	Вкусвилл	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
56	86463a6cac402bfda0d381168d46554f	2024-04-02 08:45:00	450.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
57	86463a6cac402bfda0d381168d46554f	2024-04-11 17:30:00	4500.00	RUB	5812	Якитория	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
58	86463a6cac402bfda0d381168d46554f	2024-04-20 10:15:00	780.00	RUB	5912	Ригла	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
59	86463a6cac402bfda0d381168d46554f	2024-05-05 14:00:00	1650.00	RUB	5411	Перекрёсток	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
60	86463a6cac402bfda0d381168d46554f	2024-05-18 19:20:00	350.00	RUB	7832	Синема Парк	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
61	b77db32220b56a5015adc16bcb974ff8	2024-01-06 12:45:00	3200.00	RUB	5812	Кофемания	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
62	b77db32220b56a5015adc16bcb974ff8	2024-01-19 10:30:00	1100.00	RUB	5411	Лента	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
63	b77db32220b56a5015adc16bcb974ff8	2024-02-01 15:15:00	2800.00	RUB	5541	Лукойл	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
141	c2335bc3483ee04fa170be79301f1766	2024-01-15 09:30:00	38000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
64	b77db32220b56a5015adc16bcb974ff8	2024-02-12 09:40:00	650.00	RUB	4111	Автобус	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
65	b77db32220b56a5015adc16bcb974ff8	2024-02-24 17:55:00	12000.00	RUB	5311	Галерея	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
66	b77db32220b56a5015adc16bcb974ff8	2024-03-08 11:20:00	890.00	RUB	5912	Планета здоровья	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
67	b77db32220b56a5015adc16bcb974ff8	2024-03-19 14:35:00	4100.00	RUB	5812	Burger King	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
68	b77db32220b56a5015adc16bcb974ff8	2024-04-03 08:10:00	1900.00	RUB	5411	Пятёрочка	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
69	b77db32220b56a5015adc16bcb974ff8	2024-04-15 16:45:00	560.00	RUB	4111	Трамвай	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
70	b77db32220b56a5015adc16bcb974ff8	2024-04-28 12:20:00	7600.00	RUB	5732	М.Видео	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
71	b77db32220b56a5015adc16bcb974ff8	2024-05-10 10:05:00	2300.00	RUB	5812	Теремок	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
72	b77db32220b56a5015adc16bcb974ff8	2024-05-22 18:30:00	450.00	RUB	7832	Аврора	Санкт-Петербург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
73	b7ffd93b27884ecb1026947e7514ed3d	2024-01-07 09:15:00	8500.00	RUB	5311	Zara	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
74	b7ffd93b27884ecb1026947e7514ed3d	2024-01-21 14:50:00	1200.00	RUB	5411	Магнит	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
75	b7ffd93b27884ecb1026947e7514ed3d	2024-02-05 11:25:00	3400.00	RUB	5541	Роснефть	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
76	b7ffd93b27884ecb1026947e7514ed3d	2024-02-18 16:40:00	780.00	RUB	5912	Аптека 36.6	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
77	b7ffd93b27884ecb1026947e7514ed3d	2024-03-02 09:05:00	2600.00	RUB	5812	KFC	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
78	b7ffd93b27884ecb1026947e7514ed3d	2024-03-14 13:30:00	450.00	RUB	4111	Метро	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
79	b7ffd93b27884ecb1026947e7514ed3d	2024-03-27 18:15:00	11000.00	RUB	5732	Эльдорадо	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
80	b7ffd93b27884ecb1026947e7514ed3d	2024-04-08 10:50:00	1500.00	RUB	5411	Вкусвилл	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
81	b7ffd93b27884ecb1026947e7514ed3d	2024-04-22 15:25:00	4800.00	RUB	5812	Гинза	Новосибирск	purchase	declined	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
82	b7ffd93b27884ecb1026947e7514ed3d	2024-05-06 09:00:00	1800.00	RUB	5999	Fix Price	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
83	b7ffd93b27884ecb1026947e7514ed3d	2024-05-20 14:35:00	650.00	RUB	5912	Ригла	Новосибирск	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
84	31ce0ae7081e61d01e17f4fbcd0382e0	2024-01-08 14:30:00	450.00	RUB	4111	Метро	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
85	31ce0ae7081e61d01e17f4fbcd0382e0	2024-01-22 10:15:00	2300.00	RUB	5812	Шоколадница	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
86	31ce0ae7081e61d01e17f4fbcd0382e0	2024-02-04 16:50:00	1100.00	RUB	5411	Перекрёсток	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
87	31ce0ae7081e61d01e17f4fbcd0382e0	2024-02-16 09:25:00	4500.00	RUB	5541	Газпромнефть	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
88	31ce0ae7081e61d01e17f4fbcd0382e0	2024-02-27 14:00:00	8900.00	RUB	5311	Гринвич	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
89	31ce0ae7081e61d01e17f4fbcd0382e0	2024-03-10 11:35:00	560.00	RUB	5912	Планета здоровья	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
90	31ce0ae7081e61d01e17f4fbcd0382e0	2024-03-23 17:10:00	3200.00	RUB	5812	Якитория	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
91	31ce0ae7081e61d01e17f4fbcd0382e0	2024-04-05 08:45:00	1700.00	RUB	5411	Лента	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
92	31ce0ae7081e61d01e17f4fbcd0382e0	2024-04-18 15:20:00	13000.00	RUB	5732	DNS	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
93	31ce0ae7081e61d01e17f4fbcd0382e0	2024-05-01 10:55:00	450.00	RUB	4111	Автобус	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
94	31ce0ae7081e61d01e17f4fbcd0382e0	2024-05-14 16:30:00	2800.00	RUB	5812	Burger King	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
95	31ce0ae7081e61d01e17f4fbcd0382e0	2024-05-27 12:05:00	900.00	RUB	5999	Читай-город	Екатеринбург	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
96	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-01-09 18:00:00	2100.00	RUB	5912	Аптека 36.6	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
97	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-01-23 11:35:00	3400.00	RUB	5541	Лукойл	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
98	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-02-06 08:10:00	1300.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
99	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-02-19 14:45:00	5600.00	RUB	5812	Чайхона №1	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
100	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-03-03 10:20:00	450.00	RUB	4111	Метро	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
101	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-03-16 16:55:00	9800.00	RUB	5311	Мега	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
102	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-03-29 12:30:00	2700.00	RUB	5541	Татнефть	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
103	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-04-10 09:05:00	1600.00	RUB	5411	Магнит	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
104	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-04-23 15:40:00	4200.00	RUB	5812	KFC	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
105	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-05-07 11:15:00	780.00	RUB	5912	Ригла	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
106	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-05-19 17:50:00	6200.00	RUB	5732	Samsung	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
107	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-05-28 08:25:00	1100.00	RUB	5411	Вкусвилл	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
108	2cbf08d6d6c2b31b94d36cb7f3f29275	2024-06-05 14:00:00	350.00	RUB	7832	Синема Парк	Казань	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
109	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-01-10 11:20:00	15000.00	RUB	5311	DNS	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
110	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-01-24 16:55:00	2400.00	RUB	5812	Якитория	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
111	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-02-07 10:30:00	1100.00	RUB	5411	Перекрёсток	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
112	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-02-20 15:05:00	3800.00	RUB	5541	Лукойл	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
113	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-03-05 09:40:00	890.00	RUB	5912	Аптека 36.6	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
114	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-03-18 14:15:00	450.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
115	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-04-01 11:50:00	7200.00	RUB	5732	М.Видео	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
116	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-04-14 17:25:00	1900.00	RUB	5411	Вкусвилл	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
117	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-05-02 09:00:00	3100.00	RUB	5812	Кофемания	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
118	a2e92e7ae62a8f49f3cfad77fd73e09e	2024-05-16 14:35:00	1400.00	RUB	5999	Читай-город	Москва	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
119	f2e35014b9478d853b50c8e599ccf1ac	2024-01-11 16:45:00	700.00	RUB	5411	Магнит	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
120	f2e35014b9478d853b50c8e599ccf1ac	2024-01-25 12:20:00	2900.00	RUB	5812	Burger King	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
121	f2e35014b9478d853b50c8e599ccf1ac	2024-02-08 08:55:00	4200.00	RUB	5541	Роснефть	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
122	f2e35014b9478d853b50c8e599ccf1ac	2024-02-21 15:30:00	650.00	RUB	4111	Автобус	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
123	f2e35014b9478d853b50c8e599ccf1ac	2024-03-06 11:05:00	10500.00	RUB	5311	Фантастика	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
124	f2e35014b9478d853b50c8e599ccf1ac	2024-03-19 17:40:00	1200.00	RUB	5411	Пятёрочка	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
125	f2e35014b9478d853b50c8e599ccf1ac	2024-04-02 09:15:00	560.00	RUB	5912	Ригла	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
126	f2e35014b9478d853b50c8e599ccf1ac	2024-04-15 14:50:00	8900.00	RUB	5732	DNS	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
127	f2e35014b9478d853b50c8e599ccf1ac	2024-05-01 10:25:00	3400.00	RUB	5812	KFC	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
128	f2e35014b9478d853b50c8e599ccf1ac	2024-05-13 16:00:00	1700.00	RUB	5411	Лента	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
129	f2e35014b9478d853b50c8e599ccf1ac	2024-05-26 11:35:00	400.00	RUB	7832	Киномакс	Нижний Новгород	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
130	d17176b613a57a9f6cbb35bc1638b11f	2024-01-12 08:30:00	5600.00	RUB	5812	Burger King	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
131	d17176b613a57a9f6cbb35bc1638b11f	2024-01-26 14:05:00	1300.00	RUB	5411	Магнит	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
132	d17176b613a57a9f6cbb35bc1638b11f	2024-02-09 10:40:00	3600.00	RUB	5541	Лукойл	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
133	d17176b613a57a9f6cbb35bc1638b11f	2024-02-22 16:15:00	780.00	RUB	5912	Аптека 36.6	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
134	d17176b613a57a9f6cbb35bc1638b11f	2024-03-07 09:50:00	7400.00	RUB	5311	Красная площадь	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
135	d17176b613a57a9f6cbb35bc1638b11f	2024-03-20 15:25:00	450.00	RUB	4111	Автобус	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
136	d17176b613a57a9f6cbb35bc1638b11f	2024-04-04 11:00:00	2100.00	RUB	5812	Чайхона №1	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
137	d17176b613a57a9f6cbb35bc1638b11f	2024-04-17 17:35:00	11000.00	RUB	5732	Эльдорадо	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
138	d17176b613a57a9f6cbb35bc1638b11f	2024-05-03 09:10:00	1600.00	RUB	5411	Перекрёсток	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
139	d17176b613a57a9f6cbb35bc1638b11f	2024-05-17 14:45:00	2800.00	RUB	5812	Якитория	Краснодар	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
140	c2335bc3483ee04fa170be79301f1766	2024-01-13 20:15:00	45000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
142	c2335bc3483ee04fa170be79301f1766	2024-01-28 14:00:00	42000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
143	c2335bc3483ee04fa170be79301f1766	2024-02-10 11:45:00	51000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
144	c2335bc3483ee04fa170be79301f1766	2024-02-23 16:20:00	39000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
145	c2335bc3483ee04fa170be79301f1766	2024-03-07 08:55:00	47000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
146	c2335bc3483ee04fa170be79301f1766	2024-03-20 15:30:00	43000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
147	c2335bc3483ee04fa170be79301f1766	2024-04-02 10:05:00	36000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
148	c2335bc3483ee04fa170be79301f1766	2024-04-15 17:40:00	55000.00	RUB	7011	Marriott	Самара	purchase	success	2026-06-20 11:06:23.932624	tx_system	t	2026-06-20 11:06:23.932624	etl_user	f
149	13c76899fb85e6d585ac7dca0f1592e4	2024-01-02 09:15:00	1200.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
150	051cd84fb9cc5d41b297f789c97179c8	2024-01-02 11:30:00	890.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
151	2c57c22c3172340709206b69b09af91e	2024-01-03 13:45:00	2100.00	RUB	5411	Пятёрочка	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
152	1a655a3c9acf92ba96c3cbd01056a6e4	2024-01-04 18:20:00	650.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
153	1019ec9d35eccc7f727164f02827ae71	2024-01-05 09:00:00	1450.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
154	74ba39b275456d6c87e5ad2ba7ba0d9c	2024-01-06 12:30:00	3200.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
155	cccab353dbd4c89f5025a47b2c182284	2024-01-06 14:15:00	780.00	RUB	5411	Пятёрочка	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
156	2e37bca84257c2f1bb6e2ec31ed3129e	2024-01-07 10:50:00	1100.00	RUB	5411	Пятёрочка	Новосибирск	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
157	ad21653fb3d470a799eba9968537a34b	2024-01-07 17:25:00	2400.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
158	08d29326c1e2fed2fd468254df8f1f52	2024-01-08 08:40:00	560.00	RUB	5411	Пятёрочка	Краснодар	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
159	1118c8a912757d2b1069a2ad974dfcce	2024-01-09 19:10:00	1800.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
160	2fb94a26ea921b25e3cfaf83a7d23f86	2024-01-10 11:20:00	920.00	RUB	5411	Пятёрочка	Самара	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
161	c1262a319362dc7e46c2999968eb253a	2024-01-11 15:35:00	3400.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
162	c14c8ff146dc25cf2cff54334f7417a8	2024-01-12 09:55:00	670.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
163	1b4dfbdd4d8bba68eec217b639d070ca	2024-01-13 18:00:00	1550.00	RUB	5411	Пятёрочка	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
164	4db4802622eaf31ea48bfcbfeedb270c	2024-01-14 12:15:00	2200.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
165	46f11768f7cef80132f6ff8c6843a058	2024-01-15 10:30:00	880.00	RUB	5411	Пятёрочка	Нижний Новгород	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
166	fe60d9deb07c243a2ebbe1c4f0eb8fa4	2024-01-16 16:45:00	1700.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
167	d9cb5930f320f334fa0691efc85e845f	2024-01-17 09:20:00	430.00	RUB	5411	Пятёрочка	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
168	3ea95560ccca60e8538adc55f99a6edd	2024-01-18 14:50:00	2600.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
169	44e09a74c39ed9d9b80f2bedd5181d32	2024-01-19 11:05:00	1350.00	RUB	5411	Пятёрочка	Краснодар	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
170	f26838f490873e4ffa6c10000f29372d	2024-01-20 17:30:00	790.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
171	63a60d5282c045c2759f59f31b91ecf3	2024-01-21 10:15:00	1900.00	RUB	5411	Пятёрочка	Самара	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
172	40556da66f53c530af922e2a5771740d	2024-01-22 13:40:00	560.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
173	ded0c48d679491231b7a90f78783a04b	2024-01-23 08:55:00	2800.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
174	13c76899fb85e6d585ac7dca0f1592e4	2024-01-02 08:30:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
175	051cd84fb9cc5d41b297f789c97179c8	2024-01-03 07:45:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
176	2c57c22c3172340709206b69b09af91e	2024-01-04 08:15:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
177	1a655a3c9acf92ba96c3cbd01056a6e4	2024-01-05 07:50:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
178	1019ec9d35eccc7f727164f02827ae71	2024-01-06 08:05:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
179	74ba39b275456d6c87e5ad2ba7ba0d9c	2024-01-07 18:30:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
180	cccab353dbd4c89f5025a47b2c182284	2024-01-08 07:55:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
181	2e37bca84257c2f1bb6e2ec31ed3129e	2024-01-09 18:45:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
182	ad21653fb3d470a799eba9968537a34b	2024-01-10 08:20:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
183	08d29326c1e2fed2fd468254df8f1f52	2024-01-11 17:55:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
184	1118c8a912757d2b1069a2ad974dfcce	2024-01-12 08:10:00	55.00	RUB	4111	Метро	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
185	2fb94a26ea921b25e3cfaf83a7d23f86	2024-01-13 19:00:00	55.00	RUB	4111	Метро	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
186	c1262a319362dc7e46c2999968eb253a	2024-01-14 07:40:00	55.00	RUB	4111	Метро	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
187	c14c8ff146dc25cf2cff54334f7417a8	2024-01-15 18:15:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
188	1b4dfbdd4d8bba68eec217b639d070ca	2024-01-16 08:35:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
189	4db4802622eaf31ea48bfcbfeedb270c	2024-01-17 17:50:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
190	46f11768f7cef80132f6ff8c6843a058	2024-01-18 08:00:00	55.00	RUB	4111	Метро	Новосибирск	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
191	fe60d9deb07c243a2ebbe1c4f0eb8fa4	2024-01-19 19:15:00	55.00	RUB	4111	Метро	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
192	d9cb5930f320f334fa0691efc85e845f	2024-01-20 08:25:00	55.00	RUB	4111	Метро	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
193	3ea95560ccca60e8538adc55f99a6edd	2024-01-21 18:50:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
194	f0d7fb9fb2fe112c0321d9e53120ff94	2024-01-05 13:00:00	4500.00	RUB	5812	Кофемания	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
195	bd54775ae3dff3c32650a4d55ef687f7	2024-01-06 20:30:00	8900.00	RUB	5812	Якитория	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
196	6dc774b4932a7d7bb6d38f976f16ddbb	2024-01-07 14:15:00	2300.00	RUB	5812	Шоколадница	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
197	455febaf1a66ab9ada96bbb04c66a325	2024-01-12 19:45:00	6700.00	RUB	5812	Гинза	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
198	34f7afa3384d9e9362c7a1f81dba1d74	2024-01-13 13:30:00	1800.00	RUB	5812	KFC	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
199	d7071917a1bdad1dcc649d7c6f6171cb	2024-01-14 20:00:00	3400.00	RUB	5812	Burger King	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
200	2d6bbb7f244cbec701170225aa044d23	2024-01-19 14:45:00	5200.00	RUB	5812	Чайхона №1	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
201	4dbf0d5b7af1473e4510e2703ae8c7e5	2024-01-20 20:15:00	2100.00	RUB	5812	Теремок	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
202	4c381c194283ed3fdda088402a7d1e22	2024-01-25 13:00:00	7800.00	RUB	5812	Новиков	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
203	853edf9fd145780210f8aeb2501495e0	2024-01-26 19:30:00	1500.00	RUB	5812	KFC	Краснодар	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
204	f6f59ab82bae5b8acaad2fe7489888a3	2024-01-27 14:15:00	4300.00	RUB	5812	Кофемания	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
205	8bd40b59e1a7bffb3a661ae5809f05c3	2024-01-28 20:45:00	9200.00	RUB	5812	Белуга	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
206	b8976f5ac7c42d377f16f782bdf29377	2024-01-29 13:30:00	2600.00	RUB	5812	Шоколадница	Нижний Новгород	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
207	cc2739e03a55a2baf5079f4ab0f7b314	2024-01-30 19:00:00	3800.00	RUB	5812	Якитория	Самара	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
208	f2d81545d56b9a97be8cd346f2f069b3	2024-01-31 14:45:00	1200.00	RUB	5812	Burger King	Москва	purchase	declined	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
209	f0d7fb9fb2fe112c0321d9e53120ff94	2024-01-08 07:30:00	3200.00	RUB	5541	Лукойл	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
210	bd54775ae3dff3c32650a4d55ef687f7	2024-01-10 16:45:00	4100.00	RUB	5541	Роснефть	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
211	6dc774b4932a7d7bb6d38f976f16ddbb	2024-01-15 08:20:00	2800.00	RUB	5541	Газпромнефть	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
212	455febaf1a66ab9ada96bbb04c66a325	2024-01-17 17:00:00	5600.00	RUB	5541	Лукойл	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
213	34f7afa3384d9e9362c7a1f81dba1d74	2024-01-22 07:45:00	3900.00	RUB	5541	Татнефть	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
214	d7071917a1bdad1dcc649d7c6f6171cb	2024-01-24 16:30:00	4500.00	RUB	5541	Роснефть	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
215	2d6bbb7f244cbec701170225aa044d23	2024-01-26 08:10:00	2600.00	RUB	5541	Лукойл	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
216	4dbf0d5b7af1473e4510e2703ae8c7e5	2024-01-28 17:45:00	3300.00	RUB	5541	Газпромнефть	Краснодар	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
217	4c381c194283ed3fdda088402a7d1e22	2024-01-30 07:55:00	4800.00	RUB	5541	Лукойл	Новосибирск	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
218	853edf9fd145780210f8aeb2501495e0	2024-01-31 16:15:00	2100.00	RUB	5541	Роснефть	Самара	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
219	13c76899fb85e6d585ac7dca0f1592e4	2024-02-01 10:20:00	1650.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
220	051cd84fb9cc5d41b297f789c97179c8	2024-02-02 14:35:00	980.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
221	2c57c22c3172340709206b69b09af91e	2024-02-03 09:50:00	2300.00	RUB	5411	Пятёрочка	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
222	1a655a3c9acf92ba96c3cbd01056a6e4	2024-02-05 18:05:00	750.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
223	1019ec9d35eccc7f727164f02827ae71	2024-02-07 11:20:00	1400.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
224	74ba39b275456d6c87e5ad2ba7ba0d9c	2024-02-09 15:35:00	3100.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
225	cccab353dbd4c89f5025a47b2c182284	2024-02-10 09:50:00	820.00	RUB	5411	Пятёрочка	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
226	2e37bca84257c2f1bb6e2ec31ed3129e	2024-02-12 17:05:00	1250.00	RUB	5411	Пятёрочка	Новосибирск	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
227	ad21653fb3d470a799eba9968537a34b	2024-02-14 11:20:00	2700.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
228	08d29326c1e2fed2fd468254df8f1f52	2024-02-16 15:35:00	610.00	RUB	5411	Пятёрочка	Краснодар	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
229	1118c8a912757d2b1069a2ad974dfcce	2024-02-17 09:50:00	1900.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
230	2fb94a26ea921b25e3cfaf83a7d23f86	2024-02-19 18:05:00	870.00	RUB	5411	Пятёрочка	Самара	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
231	c1262a319362dc7e46c2999968eb253a	2024-02-21 11:20:00	3500.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
232	c14c8ff146dc25cf2cff54334f7417a8	2024-02-23 15:35:00	720.00	RUB	5411	Пятёрочка	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
233	1b4dfbdd4d8bba68eec217b639d070ca	2024-02-24 09:50:00	1600.00	RUB	5411	Пятёрочка	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
234	4db4802622eaf31ea48bfcbfeedb270c	2024-02-26 18:05:00	2200.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
235	46f11768f7cef80132f6ff8c6843a058	2024-02-27 11:20:00	940.00	RUB	5411	Пятёрочка	Нижний Новгород	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
236	fe60d9deb07c243a2ebbe1c4f0eb8fa4	2024-02-28 15:35:00	1750.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
237	d9cb5930f320f334fa0691efc85e845f	2024-02-29 09:50:00	480.00	RUB	5411	Пятёрочка	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
238	3ea95560ccca60e8538adc55f99a6edd	2024-02-29 18:05:00	2800.00	RUB	5411	Пятёрочка	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
239	44e09a74c39ed9d9b80f2bedd5181d32	2024-02-01 07:40:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
240	f26838f490873e4ffa6c10000f29372d	2024-02-02 18:55:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
241	63a60d5282c045c2759f59f31b91ecf3	2024-02-05 08:10:00	55.00	RUB	4111	Метро	Санкт-Петербург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
242	40556da66f53c530af922e2a5771740d	2024-02-07 19:25:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
243	ded0c48d679491231b7a90f78783a04b	2024-02-09 07:40:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
244	f0d7fb9fb2fe112c0321d9e53120ff94	2024-02-12 18:55:00	55.00	RUB	4111	Метро	Новосибирск	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
245	bd54775ae3dff3c32650a4d55ef687f7	2024-02-14 08:10:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
246	6dc774b4932a7d7bb6d38f976f16ddbb	2024-02-16 19:25:00	55.00	RUB	4111	Метро	Екатеринбург	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
247	455febaf1a66ab9ada96bbb04c66a325	2024-02-19 07:40:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
248	34f7afa3384d9e9362c7a1f81dba1d74	2024-02-21 18:55:00	55.00	RUB	4111	Метро	Казань	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
249	d7071917a1bdad1dcc649d7c6f6171cb	2024-02-23 08:10:00	55.00	RUB	4111	Метро	Москва	purchase	success	2026-06-20 11:08:16.994268	tx_system	t	2026-06-20 11:08:16.994268	etl_user	f
\.


--
-- TOC entry 5636 (class 0 OID 0)
-- Dependencies: 287
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_card_products_card_product_id_seq', 14, true);


--
-- TOC entry 5637 (class 0 OID 0)
-- Dependencies: 277
-- Name: dict_cities_city_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_cities_city_id_seq', 12, true);


--
-- TOC entry 5638 (class 0 OID 0)
-- Dependencies: 279
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_currencies_currency_id_seq', 12, true);


--
-- TOC entry 5639 (class 0 OID 0)
-- Dependencies: 283
-- Name: dict_departments_department_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_departments_department_id_seq', 12, true);


--
-- TOC entry 5640 (class 0 OID 0)
-- Dependencies: 285
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_employees_employee_id_seq', 12, true);


--
-- TOC entry 5641 (class 0 OID 0)
-- Dependencies: 281
-- Name: dict_mcc_mcc_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dict_mcc_mcc_id_seq', 12, true);


--
-- TOC entry 5642 (class 0 OID 0)
-- Dependencies: 293
-- Name: dim_campaigns_campaign_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dim_campaigns_campaign_id_seq', 10, true);


--
-- TOC entry 5643 (class 0 OID 0)
-- Dependencies: 291
-- Name: dim_cards_card_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dim_cards_card_id_seq', 50, true);


--
-- TOC entry 5644 (class 0 OID 0)
-- Dependencies: 289
-- Name: dim_clients_client_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.dim_clients_client_id_seq', 50, true);


--
-- TOC entry 5645 (class 0 OID 0)
-- Dependencies: 297
-- Name: fact_campaign_clients_campaign_client_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.fact_campaign_clients_campaign_client_id_seq', 20, true);


--
-- TOC entry 5646 (class 0 OID 0)
-- Dependencies: 299
-- Name: fact_campaign_rewards_reward_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.fact_campaign_rewards_reward_id_seq', 20, true);


--
-- TOC entry 5647 (class 0 OID 0)
-- Dependencies: 295
-- Name: fact_transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: dds; Owner: postgres
--

SELECT pg_catalog.setval('dds.fact_transactions_transaction_id_seq', 240, true);


--
-- TOC entry 5648 (class 0 OID 0)
-- Dependencies: 232
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE SET; Schema: md; Owner: postgres
--

SELECT pg_catalog.setval('md.dict_card_products_card_product_id_seq', 13, true);


--
-- TOC entry 5649 (class 0 OID 0)
-- Dependencies: 223
-- Name: dict_cities_city_id_seq; Type: SEQUENCE SET; Schema: md; Owner: postgres
--

SELECT pg_catalog.setval('md.dict_cities_city_id_seq', 12, true);


--
-- TOC entry 5650 (class 0 OID 0)
-- Dependencies: 225
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE SET; Schema: md; Owner: postgres
--

SELECT pg_catalog.setval('md.dict_currencies_currency_id_seq', 11, true);


--
-- TOC entry 5651 (class 0 OID 0)
-- Dependencies: 228
-- Name: dict_departments_department_id_seq; Type: SEQUENCE SET; Schema: md; Owner: postgres
--

SELECT pg_catalog.setval('md.dict_departments_department_id_seq', 12, true);


--
-- TOC entry 5652 (class 0 OID 0)
-- Dependencies: 230
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE SET; Schema: md; Owner: postgres
--

SELECT pg_catalog.setval('md.dict_employees_employee_id_seq', 11, true);


--
-- TOC entry 5653 (class 0 OID 0)
-- Dependencies: 273
-- Name: campaign_clients_campaign_client_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.campaign_clients_campaign_client_id_seq', 20, true);


--
-- TOC entry 5654 (class 0 OID 0)
-- Dependencies: 275
-- Name: campaign_rewards_reward_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.campaign_rewards_reward_id_seq', 20, true);


--
-- TOC entry 5655 (class 0 OID 0)
-- Dependencies: 271
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.campaigns_campaign_id_seq', 10, true);


--
-- TOC entry 5656 (class 0 OID 0)
-- Dependencies: 267
-- Name: cards_card_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.cards_card_id_seq', 50, true);


--
-- TOC entry 5657 (class 0 OID 0)
-- Dependencies: 265
-- Name: clients_client_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.clients_client_id_seq', 50, true);


--
-- TOC entry 5658 (class 0 OID 0)
-- Dependencies: 263
-- Name: dict_card_products_card_product_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.dict_card_products_card_product_id_seq', 14, true);


--
-- TOC entry 5659 (class 0 OID 0)
-- Dependencies: 254
-- Name: dict_cities_city_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.dict_cities_city_id_seq', 12, true);


--
-- TOC entry 5660 (class 0 OID 0)
-- Dependencies: 256
-- Name: dict_currencies_currency_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.dict_currencies_currency_id_seq', 12, true);


--
-- TOC entry 5661 (class 0 OID 0)
-- Dependencies: 259
-- Name: dict_departments_department_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.dict_departments_department_id_seq', 12, true);


--
-- TOC entry 5662 (class 0 OID 0)
-- Dependencies: 261
-- Name: dict_employees_employee_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.dict_employees_employee_id_seq', 12, true);


--
-- TOC entry 5663 (class 0 OID 0)
-- Dependencies: 269
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: ods; Owner: postgres
--

SELECT pg_catalog.setval('ods.transactions_transaction_id_seq', 240, true);


--
-- TOC entry 5664 (class 0 OID 0)
-- Dependencies: 250
-- Name: campaign_clients_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.campaign_clients_stg_id_seq', 20, true);


--
-- TOC entry 5665 (class 0 OID 0)
-- Dependencies: 252
-- Name: campaign_rewards_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.campaign_rewards_stg_id_seq', 20, true);


--
-- TOC entry 5666 (class 0 OID 0)
-- Dependencies: 248
-- Name: campaigns_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.campaigns_stg_id_seq', 10, true);


--
-- TOC entry 5667 (class 0 OID 0)
-- Dependencies: 301
-- Name: cards_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.cards_stg_id_seq', 50, true);


--
-- TOC entry 5668 (class 0 OID 0)
-- Dependencies: 246
-- Name: clients_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.clients_stg_id_seq', 50, true);


--
-- TOC entry 5669 (class 0 OID 0)
-- Dependencies: 244
-- Name: dict_card_products_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_card_products_stg_id_seq', 14, true);


--
-- TOC entry 5670 (class 0 OID 0)
-- Dependencies: 234
-- Name: dict_cities_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_cities_stg_id_seq', 12, true);


--
-- TOC entry 5671 (class 0 OID 0)
-- Dependencies: 236
-- Name: dict_currencies_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_currencies_stg_id_seq', 12, true);


--
-- TOC entry 5672 (class 0 OID 0)
-- Dependencies: 240
-- Name: dict_departments_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_departments_stg_id_seq', 12, true);


--
-- TOC entry 5673 (class 0 OID 0)
-- Dependencies: 242
-- Name: dict_employees_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_employees_stg_id_seq', 12, true);


--
-- TOC entry 5674 (class 0 OID 0)
-- Dependencies: 238
-- Name: dict_mcc_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.dict_mcc_stg_id_seq', 12, true);


--
-- TOC entry 5675 (class 0 OID 0)
-- Dependencies: 303
-- Name: transactions_stg_id_seq; Type: SEQUENCE SET; Schema: stg; Owner: postgres
--

SELECT pg_catalog.setval('stg.transactions_stg_id_seq', 249, true);


--
-- TOC entry 5288 (class 2606 OID 17062)
-- Name: dict_card_products dict_card_products_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_card_products
    ADD CONSTRAINT dict_card_products_pkey PRIMARY KEY (card_product_id);


--
-- TOC entry 5290 (class 2606 OID 17064)
-- Name: dict_card_products dict_card_products_product_code_key; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_card_products
    ADD CONSTRAINT dict_card_products_product_code_key UNIQUE (product_code);


--
-- TOC entry 5270 (class 2606 OID 16967)
-- Name: dict_cities dict_cities_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_cities
    ADD CONSTRAINT dict_cities_pkey PRIMARY KEY (city_id);


--
-- TOC entry 5272 (class 2606 OID 16980)
-- Name: dict_currencies dict_currencies_currency_code_key; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_currencies
    ADD CONSTRAINT dict_currencies_currency_code_key UNIQUE (currency_code);


--
-- TOC entry 5274 (class 2606 OID 16978)
-- Name: dict_currencies dict_currencies_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_currencies
    ADD CONSTRAINT dict_currencies_pkey PRIMARY KEY (currency_id);


--
-- TOC entry 5280 (class 2606 OID 17006)
-- Name: dict_departments dict_departments_department_code_key; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_departments
    ADD CONSTRAINT dict_departments_department_code_key UNIQUE (department_code);


--
-- TOC entry 5282 (class 2606 OID 17004)
-- Name: dict_departments dict_departments_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_departments
    ADD CONSTRAINT dict_departments_pkey PRIMARY KEY (department_id);


--
-- TOC entry 5284 (class 2606 OID 17032)
-- Name: dict_employees dict_employees_email_key; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees
    ADD CONSTRAINT dict_employees_email_key UNIQUE (email);


--
-- TOC entry 5286 (class 2606 OID 17030)
-- Name: dict_employees dict_employees_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees
    ADD CONSTRAINT dict_employees_pkey PRIMARY KEY (employee_id);


--
-- TOC entry 5276 (class 2606 OID 16993)
-- Name: dict_mcc dict_mcc_mcc_code_key; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_mcc
    ADD CONSTRAINT dict_mcc_mcc_code_key UNIQUE (mcc_code);


--
-- TOC entry 5278 (class 2606 OID 16991)
-- Name: dict_mcc dict_mcc_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_mcc
    ADD CONSTRAINT dict_mcc_pkey PRIMARY KEY (mcc_id);


--
-- TOC entry 5296 (class 2606 OID 17118)
-- Name: dim_campaigns dim_campaigns_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_campaigns
    ADD CONSTRAINT dim_campaigns_pkey PRIMARY KEY (campaign_id);


--
-- TOC entry 5294 (class 2606 OID 24593)
-- Name: dim_cards dim_cards_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_cards
    ADD CONSTRAINT dim_cards_pkey PRIMARY KEY (created_dttm, updated_dttm, card_id);


--
-- TOC entry 5292 (class 2606 OID 17075)
-- Name: dim_clients dim_clients_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_clients
    ADD CONSTRAINT dim_clients_pkey PRIMARY KEY (client_id);


--
-- TOC entry 5300 (class 2606 OID 17178)
-- Name: fact_campaign_clients fact_campaign_clients_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_clients
    ADD CONSTRAINT fact_campaign_clients_pkey PRIMARY KEY (campaign_client_id);


--
-- TOC entry 5302 (class 2606 OID 17203)
-- Name: fact_campaign_rewards fact_campaign_rewards_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_rewards
    ADD CONSTRAINT fact_campaign_rewards_pkey PRIMARY KEY (reward_id);


--
-- TOC entry 5298 (class 2606 OID 17143)
-- Name: fact_transactions fact_transactions_pkey; Type: CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions
    ADD CONSTRAINT fact_transactions_pkey PRIMARY KEY (transaction_id);


--
-- TOC entry 5214 (class 2606 OID 16494)
-- Name: dict_card_products dict_card_products_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_card_products
    ADD CONSTRAINT dict_card_products_pkey PRIMARY KEY (card_product_id);


--
-- TOC entry 5216 (class 2606 OID 16496)
-- Name: dict_card_products dict_card_products_product_code_key; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_card_products
    ADD CONSTRAINT dict_card_products_product_code_key UNIQUE (product_code);


--
-- TOC entry 5198 (class 2606 OID 16404)
-- Name: dict_cities dict_cities_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_cities
    ADD CONSTRAINT dict_cities_pkey PRIMARY KEY (city_id);


--
-- TOC entry 5200 (class 2606 OID 16417)
-- Name: dict_currencies dict_currencies_currency_code_key; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_currencies
    ADD CONSTRAINT dict_currencies_currency_code_key UNIQUE (currency_code);


--
-- TOC entry 5202 (class 2606 OID 16415)
-- Name: dict_currencies dict_currencies_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_currencies
    ADD CONSTRAINT dict_currencies_pkey PRIMARY KEY (currency_id);


--
-- TOC entry 5206 (class 2606 OID 16439)
-- Name: dict_departments dict_departments_department_code_key; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_departments
    ADD CONSTRAINT dict_departments_department_code_key UNIQUE (department_code);


--
-- TOC entry 5208 (class 2606 OID 16437)
-- Name: dict_departments dict_departments_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_departments
    ADD CONSTRAINT dict_departments_pkey PRIMARY KEY (department_id);


--
-- TOC entry 5210 (class 2606 OID 16464)
-- Name: dict_employees dict_employees_email_key; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees
    ADD CONSTRAINT dict_employees_email_key UNIQUE (email);


--
-- TOC entry 5212 (class 2606 OID 16462)
-- Name: dict_employees dict_employees_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees
    ADD CONSTRAINT dict_employees_pkey PRIMARY KEY (employee_id);


--
-- TOC entry 5204 (class 2606 OID 16426)
-- Name: dict_mcc dict_mcc_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_mcc
    ADD CONSTRAINT dict_mcc_pkey PRIMARY KEY (mcc_code);


--
-- TOC entry 5310 (class 2606 OID 24591)
-- Name: ltv ltv_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.ltv
    ADD CONSTRAINT ltv_pkey PRIMARY KEY (product_name);


--
-- TOC entry 5308 (class 2606 OID 17469)
-- Name: transaction_sum transaction_sum_pkey; Type: CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.transaction_sum
    ADD CONSTRAINT transaction_sum_pkey PRIMARY KEY (product_code);


--
-- TOC entry 5266 (class 2606 OID 16860)
-- Name: campaign_clients campaign_clients_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_clients
    ADD CONSTRAINT campaign_clients_pkey PRIMARY KEY (campaign_client_id);


--
-- TOC entry 5268 (class 2606 OID 16885)
-- Name: campaign_rewards campaign_rewards_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_rewards
    ADD CONSTRAINT campaign_rewards_pkey PRIMARY KEY (reward_id);


--
-- TOC entry 5264 (class 2606 OID 16835)
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (campaign_id);


--
-- TOC entry 5260 (class 2606 OID 16773)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (card_id);


--
-- TOC entry 5258 (class 2606 OID 16758)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- TOC entry 5254 (class 2606 OID 16745)
-- Name: dict_card_products dict_card_products_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_card_products
    ADD CONSTRAINT dict_card_products_pkey PRIMARY KEY (card_product_id);


--
-- TOC entry 5256 (class 2606 OID 16747)
-- Name: dict_card_products dict_card_products_product_code_key; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_card_products
    ADD CONSTRAINT dict_card_products_product_code_key UNIQUE (product_code);


--
-- TOC entry 5238 (class 2606 OID 16655)
-- Name: dict_cities dict_cities_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_cities
    ADD CONSTRAINT dict_cities_pkey PRIMARY KEY (city_id);


--
-- TOC entry 5240 (class 2606 OID 16668)
-- Name: dict_currencies dict_currencies_currency_code_key; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_currencies
    ADD CONSTRAINT dict_currencies_currency_code_key UNIQUE (currency_code);


--
-- TOC entry 5242 (class 2606 OID 16666)
-- Name: dict_currencies dict_currencies_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_currencies
    ADD CONSTRAINT dict_currencies_pkey PRIMARY KEY (currency_id);


--
-- TOC entry 5246 (class 2606 OID 16690)
-- Name: dict_departments dict_departments_department_code_key; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_departments
    ADD CONSTRAINT dict_departments_department_code_key UNIQUE (department_code);


--
-- TOC entry 5248 (class 2606 OID 16688)
-- Name: dict_departments dict_departments_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_departments
    ADD CONSTRAINT dict_departments_pkey PRIMARY KEY (department_id);


--
-- TOC entry 5250 (class 2606 OID 16715)
-- Name: dict_employees dict_employees_email_key; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees
    ADD CONSTRAINT dict_employees_email_key UNIQUE (email);


--
-- TOC entry 5252 (class 2606 OID 16713)
-- Name: dict_employees dict_employees_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees
    ADD CONSTRAINT dict_employees_pkey PRIMARY KEY (employee_id);


--
-- TOC entry 5244 (class 2606 OID 16677)
-- Name: dict_mcc dict_mcc_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_mcc
    ADD CONSTRAINT dict_mcc_pkey PRIMARY KEY (mcc_code);


--
-- TOC entry 5262 (class 2606 OID 16798)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- TOC entry 5234 (class 2606 OID 16633)
-- Name: campaign_clients campaign_clients_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaign_clients
    ADD CONSTRAINT campaign_clients_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5236 (class 2606 OID 16644)
-- Name: campaign_rewards campaign_rewards_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaign_rewards
    ADD CONSTRAINT campaign_rewards_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5232 (class 2606 OID 16622)
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5304 (class 2606 OID 17287)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5230 (class 2606 OID 16583)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5228 (class 2606 OID 16570)
-- Name: dict_card_products dict_card_products_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_card_products
    ADD CONSTRAINT dict_card_products_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5218 (class 2606 OID 16509)
-- Name: dict_cities dict_cities_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_cities
    ADD CONSTRAINT dict_cities_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5220 (class 2606 OID 16520)
-- Name: dict_currencies dict_currencies_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_currencies
    ADD CONSTRAINT dict_currencies_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5224 (class 2606 OID 16544)
-- Name: dict_departments dict_departments_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_departments
    ADD CONSTRAINT dict_departments_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5226 (class 2606 OID 16557)
-- Name: dict_employees dict_employees_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_employees
    ADD CONSTRAINT dict_employees_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5222 (class 2606 OID 16531)
-- Name: dict_mcc dict_mcc_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.dict_mcc
    ADD CONSTRAINT dict_mcc_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5306 (class 2606 OID 17406)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: stg; Owner: postgres
--

ALTER TABLE ONLY stg.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (stg_id);


--
-- TOC entry 5339 (class 2606 OID 17012)
-- Name: dict_departments dict_departments_city_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_departments
    ADD CONSTRAINT dict_departments_city_id_fkey FOREIGN KEY (city_id) REFERENCES dds.dict_cities(city_id);


--
-- TOC entry 5340 (class 2606 OID 17007)
-- Name: dict_departments dict_departments_parent_department_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_departments
    ADD CONSTRAINT dict_departments_parent_department_id_fkey FOREIGN KEY (parent_department_id) REFERENCES dds.dict_departments(department_id);


--
-- TOC entry 5341 (class 2606 OID 17038)
-- Name: dict_employees dict_employees_city_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees
    ADD CONSTRAINT dict_employees_city_id_fkey FOREIGN KEY (city_id) REFERENCES dds.dict_cities(city_id);


--
-- TOC entry 5342 (class 2606 OID 17033)
-- Name: dict_employees dict_employees_department_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees
    ADD CONSTRAINT dict_employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES dds.dict_departments(department_id);


--
-- TOC entry 5343 (class 2606 OID 17043)
-- Name: dict_employees dict_employees_manager_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dict_employees
    ADD CONSTRAINT dict_employees_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES dds.dict_employees(employee_id);


--
-- TOC entry 5348 (class 2606 OID 17119)
-- Name: dim_campaigns dim_campaigns_card_product_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_campaigns
    ADD CONSTRAINT dim_campaigns_card_product_id_fkey FOREIGN KEY (card_product_id) REFERENCES dds.dict_card_products(card_product_id);


--
-- TOC entry 5349 (class 2606 OID 17124)
-- Name: dim_campaigns dim_campaigns_currency_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_campaigns
    ADD CONSTRAINT dim_campaigns_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES dds.dict_currencies(currency_id);


--
-- TOC entry 5350 (class 2606 OID 17129)
-- Name: dim_campaigns dim_campaigns_owner_employee_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_campaigns
    ADD CONSTRAINT dim_campaigns_owner_employee_id_fkey FOREIGN KEY (owner_employee_id) REFERENCES dds.dict_employees(employee_id);


--
-- TOC entry 5345 (class 2606 OID 17096)
-- Name: dim_cards dim_cards_card_product_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_cards
    ADD CONSTRAINT dim_cards_card_product_id_fkey FOREIGN KEY (card_product_id) REFERENCES dds.dict_card_products(card_product_id);


--
-- TOC entry 5346 (class 2606 OID 17091)
-- Name: dim_cards dim_cards_client_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_cards
    ADD CONSTRAINT dim_cards_client_id_fkey FOREIGN KEY (client_id) REFERENCES dds.dim_clients(client_id);


--
-- TOC entry 5347 (class 2606 OID 17101)
-- Name: dim_cards dim_cards_currency_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_cards
    ADD CONSTRAINT dim_cards_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES dds.dict_currencies(currency_id);


--
-- TOC entry 5344 (class 2606 OID 17076)
-- Name: dim_clients dim_clients_city_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.dim_clients
    ADD CONSTRAINT dim_clients_city_id_fkey FOREIGN KEY (city_id) REFERENCES dds.dict_cities(city_id);


--
-- TOC entry 5355 (class 2606 OID 17179)
-- Name: fact_campaign_clients fact_campaign_clients_campaign_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_clients
    ADD CONSTRAINT fact_campaign_clients_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES dds.dim_campaigns(campaign_id);


--
-- TOC entry 5356 (class 2606 OID 17184)
-- Name: fact_campaign_clients fact_campaign_clients_client_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_clients
    ADD CONSTRAINT fact_campaign_clients_client_id_fkey FOREIGN KEY (client_id) REFERENCES dds.dim_clients(client_id);


--
-- TOC entry 5357 (class 2606 OID 17204)
-- Name: fact_campaign_rewards fact_campaign_rewards_campaign_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_rewards
    ADD CONSTRAINT fact_campaign_rewards_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES dds.dim_campaigns(campaign_id);


--
-- TOC entry 5358 (class 2606 OID 17209)
-- Name: fact_campaign_rewards fact_campaign_rewards_client_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_rewards
    ADD CONSTRAINT fact_campaign_rewards_client_id_fkey FOREIGN KEY (client_id) REFERENCES dds.dim_clients(client_id);


--
-- TOC entry 5359 (class 2606 OID 17214)
-- Name: fact_campaign_rewards fact_campaign_rewards_transaction_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_campaign_rewards
    ADD CONSTRAINT fact_campaign_rewards_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES dds.fact_transactions(transaction_id);


--
-- TOC entry 5351 (class 2606 OID 17164)
-- Name: fact_transactions fact_transactions_city_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions
    ADD CONSTRAINT fact_transactions_city_id_fkey FOREIGN KEY (city_id) REFERENCES dds.dict_cities(city_id);


--
-- TOC entry 5352 (class 2606 OID 17149)
-- Name: fact_transactions fact_transactions_client_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions
    ADD CONSTRAINT fact_transactions_client_id_fkey FOREIGN KEY (client_id) REFERENCES dds.dim_clients(client_id);


--
-- TOC entry 5353 (class 2606 OID 17154)
-- Name: fact_transactions fact_transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions
    ADD CONSTRAINT fact_transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES dds.dict_currencies(currency_id);


--
-- TOC entry 5354 (class 2606 OID 17159)
-- Name: fact_transactions fact_transactions_mcc_id_fkey; Type: FK CONSTRAINT; Schema: dds; Owner: postgres
--

ALTER TABLE ONLY dds.fact_transactions
    ADD CONSTRAINT fact_transactions_mcc_id_fkey FOREIGN KEY (mcc_id) REFERENCES dds.dict_mcc(mcc_id);


--
-- TOC entry 5311 (class 2606 OID 16445)
-- Name: dict_departments dict_departments_city_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_departments
    ADD CONSTRAINT dict_departments_city_id_fkey FOREIGN KEY (city_id) REFERENCES md.dict_cities(city_id);


--
-- TOC entry 5312 (class 2606 OID 16440)
-- Name: dict_departments dict_departments_parent_department_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_departments
    ADD CONSTRAINT dict_departments_parent_department_id_fkey FOREIGN KEY (parent_department_id) REFERENCES md.dict_departments(department_id);


--
-- TOC entry 5313 (class 2606 OID 16470)
-- Name: dict_employees dict_employees_city_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees
    ADD CONSTRAINT dict_employees_city_id_fkey FOREIGN KEY (city_id) REFERENCES md.dict_cities(city_id);


--
-- TOC entry 5314 (class 2606 OID 16465)
-- Name: dict_employees dict_employees_department_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees
    ADD CONSTRAINT dict_employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES md.dict_departments(department_id);


--
-- TOC entry 5315 (class 2606 OID 16475)
-- Name: dict_employees dict_employees_manager_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.dict_employees
    ADD CONSTRAINT dict_employees_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES md.dict_employees(employee_id);


--
-- TOC entry 5360 (class 2606 OID 17483)
-- Name: transaction_per_merchant transaction_per_merchant_city_id_fkey; Type: FK CONSTRAINT; Schema: md; Owner: postgres
--

ALTER TABLE ONLY md.transaction_per_merchant
    ADD CONSTRAINT transaction_per_merchant_city_id_fkey FOREIGN KEY (city_id) REFERENCES md.dict_cities(city_id);


--
-- TOC entry 5333 (class 2606 OID 16861)
-- Name: campaign_clients campaign_clients_campaign_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_clients
    ADD CONSTRAINT campaign_clients_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES ods.campaigns(campaign_id);


--
-- TOC entry 5334 (class 2606 OID 16871)
-- Name: campaign_clients campaign_clients_card_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_clients
    ADD CONSTRAINT campaign_clients_card_id_fkey FOREIGN KEY (card_id) REFERENCES ods.cards(card_id);


--
-- TOC entry 5335 (class 2606 OID 16866)
-- Name: campaign_clients campaign_clients_client_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_clients
    ADD CONSTRAINT campaign_clients_client_id_fkey FOREIGN KEY (client_id) REFERENCES ods.clients(client_id);


--
-- TOC entry 5336 (class 2606 OID 16886)
-- Name: campaign_rewards campaign_rewards_campaign_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_rewards
    ADD CONSTRAINT campaign_rewards_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES ods.campaigns(campaign_id);


--
-- TOC entry 5337 (class 2606 OID 16891)
-- Name: campaign_rewards campaign_rewards_client_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_rewards
    ADD CONSTRAINT campaign_rewards_client_id_fkey FOREIGN KEY (client_id) REFERENCES ods.clients(client_id);


--
-- TOC entry 5338 (class 2606 OID 16896)
-- Name: campaign_rewards campaign_rewards_transaction_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaign_rewards
    ADD CONSTRAINT campaign_rewards_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES ods.transactions(transaction_id);


--
-- TOC entry 5330 (class 2606 OID 16836)
-- Name: campaigns campaigns_card_product_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaigns
    ADD CONSTRAINT campaigns_card_product_id_fkey FOREIGN KEY (card_product_id) REFERENCES ods.dict_card_products(card_product_id);


--
-- TOC entry 5331 (class 2606 OID 16841)
-- Name: campaigns campaigns_currency_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaigns
    ADD CONSTRAINT campaigns_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES ods.dict_currencies(currency_id);


--
-- TOC entry 5332 (class 2606 OID 16846)
-- Name: campaigns campaigns_owner_employee_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.campaigns
    ADD CONSTRAINT campaigns_owner_employee_id_fkey FOREIGN KEY (owner_employee_id) REFERENCES ods.dict_employees(employee_id);


--
-- TOC entry 5322 (class 2606 OID 16779)
-- Name: cards cards_card_product_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.cards
    ADD CONSTRAINT cards_card_product_id_fkey FOREIGN KEY (card_product_id) REFERENCES ods.dict_card_products(card_product_id);


--
-- TOC entry 5323 (class 2606 OID 16774)
-- Name: cards cards_client_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.cards
    ADD CONSTRAINT cards_client_id_fkey FOREIGN KEY (client_id) REFERENCES ods.clients(client_id);


--
-- TOC entry 5324 (class 2606 OID 16784)
-- Name: cards cards_currency_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.cards
    ADD CONSTRAINT cards_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES ods.dict_currencies(currency_id);


--
-- TOC entry 5321 (class 2606 OID 16759)
-- Name: clients clients_city_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.clients
    ADD CONSTRAINT clients_city_id_fkey FOREIGN KEY (city_id) REFERENCES ods.dict_cities(city_id);


--
-- TOC entry 5316 (class 2606 OID 16696)
-- Name: dict_departments dict_departments_city_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_departments
    ADD CONSTRAINT dict_departments_city_id_fkey FOREIGN KEY (city_id) REFERENCES ods.dict_cities(city_id);


--
-- TOC entry 5317 (class 2606 OID 16691)
-- Name: dict_departments dict_departments_parent_department_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_departments
    ADD CONSTRAINT dict_departments_parent_department_id_fkey FOREIGN KEY (parent_department_id) REFERENCES ods.dict_departments(department_id);


--
-- TOC entry 5318 (class 2606 OID 16721)
-- Name: dict_employees dict_employees_city_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees
    ADD CONSTRAINT dict_employees_city_id_fkey FOREIGN KEY (city_id) REFERENCES ods.dict_cities(city_id);


--
-- TOC entry 5319 (class 2606 OID 16716)
-- Name: dict_employees dict_employees_department_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees
    ADD CONSTRAINT dict_employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES ods.dict_departments(department_id);


--
-- TOC entry 5320 (class 2606 OID 16726)
-- Name: dict_employees dict_employees_manager_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.dict_employees
    ADD CONSTRAINT dict_employees_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES ods.dict_employees(employee_id);


--
-- TOC entry 5325 (class 2606 OID 16799)
-- Name: transactions transactions_card_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_card_id_fkey FOREIGN KEY (card_id) REFERENCES ods.cards(card_id);


--
-- TOC entry 5326 (class 2606 OID 16819)
-- Name: transactions transactions_city_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_city_id_fkey FOREIGN KEY (city_id) REFERENCES ods.dict_cities(city_id);


--
-- TOC entry 5327 (class 2606 OID 16804)
-- Name: transactions transactions_client_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_client_id_fkey FOREIGN KEY (client_id) REFERENCES ods.clients(client_id);


--
-- TOC entry 5328 (class 2606 OID 16809)
-- Name: transactions transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES ods.dict_currencies(currency_id);


--
-- TOC entry 5329 (class 2606 OID 16814)
-- Name: transactions transactions_mcc_code_fkey; Type: FK CONSTRAINT; Schema: ods; Owner: postgres
--

ALTER TABLE ONLY ods.transactions
    ADD CONSTRAINT transactions_mcc_code_fkey FOREIGN KEY (mcc_code) REFERENCES ods.dict_mcc(mcc_code);


-- Completed on 2026-07-16 17:12:57

--
-- PostgreSQL database dump complete
--

\unrestrict MUGG9n3nZlmxSZhX2NIXcC3gwfcKP8hRqnV15RTD3M2Tlfah1PgcvMobdZ4zKwm

-- Completed on 2026-07-16 17:12:58

--
-- PostgreSQL database cluster dump complete
--

