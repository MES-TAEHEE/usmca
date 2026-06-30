/* ============================================================================
   UOCM — USMCA Origin Compliance Management System
   Database Schema (DDL)  ·  Microsoft SQL Server (T-SQL)
   ----------------------------------------------------------------------------
   Generated from the L2/L3 design specs. 40 tables across 7 modules:
     MD  Master Data        (md_*)        9 tables
     DOC Document Mgmt      (doc_*)       7 tables
     LBL Label Mgmt         (lbl_*)       3 tables
     ORG Origin Mgmt        (org_*)       4 tables
     AUD Audit Support      (aud_*)       3 tables
     INT Integration        (int_*)       4 tables
     SYS System / Admin     (sys_*)      10 tables
   Conventions: PK = <table>_id IDENTITY (BIGINT) unless a natural code key.
                Audit columns created_by/created_at/updated_by/updated_at.
   Visual diagram: UOCM_ERD.html  ·  Browsable schema: UOCM_DB_Schema.html
                All text NVARCHAR (Unicode, KO/EN). UTC via SYSUTCDATETIME().
   ============================================================================ */

/* ========================= 1. MASTER DATA (MD) ============================= */

-- MD-04 Country (natural PK: ISO 3166-1 alpha-2)
CREATE TABLE md_country (
    country_code     CHAR(2)        NOT NULL PRIMARY KEY,           -- ISO 3166-1 alpha-2
    country_code3    CHAR(3)        NULL,                           -- ISO alpha-3
    country_name     NVARCHAR(80)   NOT NULL,
    country_name_ko  NVARCHAR(80)   NULL,
    region           NVARCHAR(40)   NULL,
    usmca_member     BIT            NOT NULL DEFAULT 0,             -- USMCA 회원국 여부
    fta_flags        NVARCHAR(100)  NULL,                           -- e.g. 'KORUS'
    is_active        BIT            NOT NULL DEFAULT 1,
    sort_order       INT            NULL,
    created_by       NVARCHAR(50)   NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by       NVARCHAR(50)   NULL,
    updated_at       DATETIME2      NULL,
    CONSTRAINT UQ_md_country_code3 UNIQUE (country_code3)
);

-- MD-05 HTS Code
CREATE TABLE md_hts (
    hts_id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    hts_code         NVARCHAR(12)   NOT NULL,                       -- e.g. 8708.30
    description      NVARCHAR(200)  NOT NULL,
    description_ko   NVARCHAR(200)  NULL,
    chapter          CHAR(2)        NULL,
    heading          CHAR(4)        NULL,
    base_duty_rate   DECIMAL(6,3)   NULL,
    usmca_pref_rate  DECIMAL(6,3)   NULL,
    origin_rule      NVARCHAR(200)  NULL,                           -- tariff shift / RVC rule
    rvc_threshold    DECIMAL(5,2)   NULL,                           -- e.g. 75.00
    effective_from   DATE           NULL,
    is_active        BIT            NOT NULL DEFAULT 1,
    created_by       NVARCHAR(50)   NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by       NVARCHAR(50)   NULL,
    updated_at       DATETIME2      NULL,
    CONSTRAINT UQ_md_hts_code UNIQUE (hts_code),
    CONSTRAINT CK_md_hts_rates CHECK (base_duty_rate >= 0 AND usmca_pref_rate >= 0)
);

-- MD-01 Supplier
CREATE TABLE md_supplier (
    supplier_id      BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    supplier_code    NVARCHAR(20)   NOT NULL,
    supplier_name    NVARCHAR(100)  NOT NULL,
    supplier_name_en NVARCHAR(100)  NULL,
    country_code     CHAR(2)        NULL,
    biz_reg_no       NVARCHAR(30)   NULL,
    address          NVARCHAR(200)  NULL,
    contact_name     NVARCHAR(50)   NULL,
    contact_email    NVARCHAR(100)  NULL,
    contact_phone    NVARCHAR(30)   NULL,
    usmca_eligible   BIT            NOT NULL DEFAULT 0,
    sap_vendor_no    NVARCHAR(20)   NULL,                           -- INT sync key
    rating           NVARCHAR(2)    NULL,
    status           NVARCHAR(10)   NOT NULL DEFAULT 'active',
    created_by       NVARCHAR(50)   NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by       NVARCHAR(50)   NULL,
    updated_at       DATETIME2      NULL,
    CONSTRAINT UQ_md_supplier_code UNIQUE (supplier_code),
    CONSTRAINT FK_md_supplier_country FOREIGN KEY (country_code) REFERENCES md_country(country_code),
    CONSTRAINT CK_md_supplier_status CHECK (status IN ('active','inactive'))
);
CREATE INDEX IX_md_supplier_country  ON md_supplier(country_code);
CREATE INDEX IX_md_supplier_sapvendor ON md_supplier(sap_vendor_no);

-- MD-02 Part / Item
CREATE TABLE md_part (
    part_id              BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    part_code            NVARCHAR(30) NOT NULL,
    part_name            NVARCHAR(100) NOT NULL,
    part_name_en         NVARCHAR(100) NULL,
    part_type            NVARCHAR(20) NOT NULL,                     -- raw/component/sub_assy/finished
    uom                  NVARCHAR(10) NULL,
    hts_id               BIGINT       NULL,
    default_origin_country CHAR(2)    NULL,
    supplier_id          BIGINT       NULL,                         -- null = in-house
    unit_cost            DECIMAL(18,4) NULL,
    currency             CHAR(3)      NOT NULL DEFAULT 'USD',
    sap_material_no      NVARCHAR(20) NULL,
    status               NVARCHAR(10) NOT NULL DEFAULT 'active',
    created_by           NVARCHAR(50) NULL,
    created_at           DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by           NVARCHAR(50) NULL,
    updated_at           DATETIME2    NULL,
    CONSTRAINT UQ_md_part_code UNIQUE (part_code),
    CONSTRAINT FK_md_part_hts FOREIGN KEY (hts_id) REFERENCES md_hts(hts_id),
    CONSTRAINT FK_md_part_country FOREIGN KEY (default_origin_country) REFERENCES md_country(country_code),
    CONSTRAINT FK_md_part_supplier FOREIGN KEY (supplier_id) REFERENCES md_supplier(supplier_id),
    CONSTRAINT CK_md_part_type CHECK (part_type IN ('raw','component','sub_assy','finished'))
);
CREATE INDEX IX_md_part_hts      ON md_part(hts_id);
CREATE INDEX IX_md_part_supplier ON md_part(supplier_id);
CREATE INDEX IX_md_part_type     ON md_part(part_type);

-- MD-03 BOM (self-referential via md_part)
CREATE TABLE md_bom (
    bom_id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    parent_part_id   BIGINT         NOT NULL,
    child_part_id    BIGINT         NOT NULL,
    bom_level        INT            NOT NULL DEFAULT 1,
    quantity         DECIMAL(18,4)  NOT NULL,
    uom              NVARCHAR(10)   NULL,
    cost_ratio       DECIMAL(9,6)   NULL,                           -- RVC weight
    unit_cost        DECIMAL(18,4)  NULL,
    bom_version      NVARCHAR(20)   NOT NULL DEFAULT 'v1',
    effective_from   DATE           NULL,
    effective_to     DATE           NULL,
    sap_bom_no       NVARCHAR(20)   NULL,
    created_by       NVARCHAR(50)   NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by       NVARCHAR(50)   NULL,
    updated_at       DATETIME2      NULL,
    CONSTRAINT UQ_md_bom UNIQUE (parent_part_id, child_part_id, bom_version),
    CONSTRAINT FK_md_bom_parent FOREIGN KEY (parent_part_id) REFERENCES md_part(part_id),
    CONSTRAINT FK_md_bom_child  FOREIGN KEY (child_part_id)  REFERENCES md_part(part_id),
    CONSTRAINT CK_md_bom_qty    CHECK (quantity > 0),
    CONSTRAINT CK_md_bom_noself CHECK (parent_part_id <> child_part_id),
    CONSTRAINT CK_md_bom_dates  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE INDEX IX_md_bom_parent ON md_bom(parent_part_id);
CREATE INDEX IX_md_bom_child  ON md_bom(child_part_id);

-- MD-08 Label Template (+ child fields). oem_id FK added later (circular with oem).
CREATE TABLE md_label_template (
    template_id      BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    template_code    NVARCHAR(20)   NOT NULL,
    template_name    NVARCHAR(100)  NOT NULL,
    oem_id           BIGINT         NULL,                           -- null = COO standard
    label_type       NVARCHAR(20)   NOT NULL DEFAULT 'COO',        -- COO / OEM
    paper_size       NVARCHAR(20)   NULL,
    barcode_type     NVARCHAR(20)   NULL,                           -- Code128/QR/DataMatrix
    version          INT            NOT NULL DEFAULT 1,
    approval_status  NVARCHAR(10)   NOT NULL DEFAULT 'draft',      -- draft/approved
    is_active        BIT            NOT NULL DEFAULT 1,
    created_by       NVARCHAR(50)   NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by       NVARCHAR(50)   NULL,
    updated_at       DATETIME2      NULL,
    CONSTRAINT UQ_md_label_template UNIQUE (template_code, version),
    CONSTRAINT CK_md_label_template_status CHECK (approval_status IN ('draft','approved'))
);

CREATE TABLE md_label_template_field (
    field_id         BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    template_id      BIGINT         NOT NULL,
    field_key        NVARCHAR(40)   NOT NULL,                       -- origin_country/part/lot/cert_no/serial
    label_text       NVARCHAR(60)   NULL,
    data_source      NVARCHAR(60)   NULL,
    is_required      BIT            NOT NULL DEFAULT 0,
    pos_x            INT            NULL,
    pos_y            INT            NULL,
    sort_order       INT            NULL,
    CONSTRAINT FK_md_ltf_template FOREIGN KEY (template_id) REFERENCES md_label_template(template_id) ON DELETE CASCADE
);
CREATE INDEX IX_md_ltf_template ON md_label_template_field(template_id);

-- MD-06 OEM Customer
CREATE TABLE md_oem_customer (
    oem_id                    BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    oem_code                  NVARCHAR(10) NOT NULL,                -- HMC / KIA / MOBIS
    oem_name                  NVARCHAR(100) NOT NULL,
    oem_name_en               NVARCHAR(100) NULL,
    customer_part_prefix      NVARCHAR(20) NULL,
    default_label_template_id BIGINT       NULL,
    coo_form_required         BIT          NOT NULL DEFAULT 1,
    submission_format         NVARCHAR(50) NULL,                    -- portal/email/EDI
    contact_name              NVARCHAR(50) NULL,
    contact_email             NVARCHAR(100) NULL,
    status                    NVARCHAR(10) NOT NULL DEFAULT 'active',
    created_by                NVARCHAR(50) NULL,
    created_at                DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by                NVARCHAR(50) NULL,
    updated_at                DATETIME2    NULL,
    CONSTRAINT UQ_md_oem_code UNIQUE (oem_code),
    CONSTRAINT FK_md_oem_template FOREIGN KEY (default_label_template_id) REFERENCES md_label_template(template_id),
    CONSTRAINT CK_md_oem_status CHECK (status IN ('active','inactive'))
);
-- resolve circular ref: md_label_template.oem_id -> md_oem_customer.oem_id
ALTER TABLE md_label_template
    ADD CONSTRAINT FK_md_label_template_oem FOREIGN KEY (oem_id) REFERENCES md_oem_customer(oem_id);

-- MD-07 Certificate Type
CREATE TABLE md_cert_type (
    cert_type_id        INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    cert_type_code      NVARCHAR(10) NOT NULL,                      -- COO/USMCA/AFFID/HTS/MILL/OEMDOC
    type_name           NVARCHAR(80) NOT NULL,
    type_name_ko        NVARCHAR(80) NULL,
    validity_months     INT          NULL,                          -- NULL = no expiry
    requires_approval   BIT          NOT NULL DEFAULT 1,
    blanket_allowed     BIT          NOT NULL DEFAULT 0,
    default_alert_tiers NVARCHAR(40) NULL DEFAULT '90,30,7',
    description         NVARCHAR(200) NULL,
    sort_order          INT          NULL,
    is_active           BIT          NOT NULL DEFAULT 1,
    created_by          NVARCHAR(50) NULL,
    created_at          DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by          NVARCHAR(50) NULL,
    updated_at          DATETIME2    NULL,
    CONSTRAINT UQ_md_cert_type_code UNIQUE (cert_type_code),
    CONSTRAINT CK_md_cert_type_validity CHECK (validity_months IS NULL OR validity_months > 0)
);

/* ========================= 2. DOCUMENT MGMT (DOC) ========================== */

-- DOC-01 Certificate (Single Source of Truth)
CREATE TABLE doc_certificate (
    certificate_id     BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    cert_no            NVARCHAR(40)  NOT NULL,
    cert_type_id       INT           NOT NULL,
    supplier_id        BIGINT        NOT NULL,
    origin_country     CHAR(2)       NULL,
    issue_date         DATE          NULL,
    expiry_date        DATE          NULL,                          -- NULL = no expiry (e.g. HTS)
    status             NVARCHAR(15)  NOT NULL DEFAULT 'pending',   -- pending/valid/expired/rejected
    current_version_id BIGINT        NULL,
    note               NVARCHAR(300) NULL,
    created_by         NVARCHAR(50)  NULL,
    created_at         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by         NVARCHAR(50)  NULL,
    updated_at         DATETIME2     NULL,
    CONSTRAINT FK_doc_cert_type     FOREIGN KEY (cert_type_id)   REFERENCES md_cert_type(cert_type_id),
    CONSTRAINT FK_doc_cert_supplier FOREIGN KEY (supplier_id)    REFERENCES md_supplier(supplier_id),
    CONSTRAINT FK_doc_cert_country  FOREIGN KEY (origin_country) REFERENCES md_country(country_code),
    CONSTRAINT CK_doc_cert_status   CHECK (status IN ('pending','valid','expired','rejected')),
    CONSTRAINT CK_doc_cert_dates    CHECK (expiry_date IS NULL OR expiry_date >= issue_date)
);
CREATE INDEX IX_doc_cert_supplier ON doc_certificate(supplier_id);
CREATE INDEX IX_doc_cert_expiry   ON doc_certificate(expiry_date);
CREATE INDEX IX_doc_cert_status   ON doc_certificate(status);

-- DOC file storage (current + historical via doc_version)
CREATE TABLE doc_file (
    file_id        BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    certificate_id BIGINT        NOT NULL,
    file_name      NVARCHAR(200) NOT NULL,
    file_path      NVARCHAR(400) NOT NULL,
    mime_type      NVARCHAR(60)  NULL,
    file_size      BIGINT        NULL,
    virus_scanned  BIT           NOT NULL DEFAULT 0,
    uploaded_by    NVARCHAR(50)  NULL,
    uploaded_at    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_doc_file_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id)
);
CREATE INDEX IX_doc_file_cert ON doc_file(certificate_id);

-- DOC applied parts (M:N certificate <-> part)
CREATE TABLE doc_certificate_part (
    cert_part_id   BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    certificate_id BIGINT NOT NULL,
    part_id        BIGINT NOT NULL,
    CONSTRAINT UQ_doc_cert_part UNIQUE (certificate_id, part_id),
    CONSTRAINT FK_doc_cp_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT FK_doc_cp_part FOREIGN KEY (part_id)        REFERENCES md_part(part_id)
);

-- DOC-05 Version history (immutable chain)
CREATE TABLE doc_version (
    version_id     BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    certificate_id BIGINT        NOT NULL,
    version_no     INT           NOT NULL,
    file_id        BIGINT        NULL,
    change_reason  NVARCHAR(200) NULL,
    is_current     BIT           NOT NULL DEFAULT 1,
    changed_by     NVARCHAR(50)  NULL,
    changed_at     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    superseded_at  DATETIME2     NULL,
    CONSTRAINT UQ_doc_version UNIQUE (certificate_id, version_no),
    CONSTRAINT FK_doc_ver_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT FK_doc_ver_file FOREIGN KEY (file_id)        REFERENCES doc_file(file_id)
);

-- DOC-04 Approval workflow header + steps
CREATE TABLE doc_approval (
    approval_id    BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    certificate_id BIGINT       NOT NULL,
    current_stage  INT          NOT NULL DEFAULT 1,
    status         NVARCHAR(12) NOT NULL DEFAULT 'submitted',     -- submitted/pending/approved/rejected
    submitted_by   NVARCHAR(50) NULL,
    submitted_at   DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    completed_at   DATETIME2    NULL,
    CONSTRAINT FK_doc_appr_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT CK_doc_appr_status CHECK (status IN ('submitted','pending','approved','rejected'))
);
CREATE INDEX IX_doc_appr_cert ON doc_approval(certificate_id);

CREATE TABLE doc_approval_step (
    step_id        BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    approval_id    BIGINT       NOT NULL,
    stage_no       INT          NOT NULL,
    role_code      NVARCHAR(20) NULL,
    approver_id    BIGINT       NULL,
    action         NVARCHAR(12) NULL,                               -- approve/reject/pending
    reason         NVARCHAR(300) NULL,
    checklist_json NVARCHAR(MAX) NULL,
    acted_at       DATETIME2    NULL,
    CONSTRAINT FK_doc_step_appr FOREIGN KEY (approval_id) REFERENCES doc_approval(approval_id) ON DELETE CASCADE
);
CREATE INDEX IX_doc_step_appr ON doc_approval_step(approval_id);

-- DOC-03 Expiry alerts (tiered D-90/30/7/expired)
CREATE TABLE doc_alert (
    alert_id       BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    certificate_id BIGINT       NOT NULL,
    tier           NVARCHAR(10) NOT NULL,                           -- D-90/D-30/D-7/expired
    scheduled_for  DATE         NOT NULL,
    channel        NVARCHAR(20) NULL,
    recipient      NVARCHAR(100) NULL,
    sent_at        DATETIME2    NULL,
    ack_at         DATETIME2    NULL,
    status         NVARCHAR(12) NOT NULL DEFAULT 'scheduled',      -- scheduled/sent/acked/failed
    CONSTRAINT FK_doc_alert_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT CK_doc_alert_status CHECK (status IN ('scheduled','sent','acked','failed'))
);
CREATE INDEX IX_doc_alert_cert ON doc_alert(certificate_id);
CREATE INDEX IX_doc_alert_sched ON doc_alert(scheduled_for, status);

-- add the current-version FK now that doc_version exists
ALTER TABLE doc_certificate
    ADD CONSTRAINT FK_doc_cert_curver FOREIGN KEY (current_version_id) REFERENCES doc_version(version_id);

/* ============================ 3. LABEL (LBL) =============================== */

-- LBL-02/03 Issued label
CREATE TABLE lbl_issue (
    issue_id       BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    serial_no      NVARCHAR(30)  NOT NULL,                          -- unique serial
    part_id        BIGINT        NOT NULL,
    oem_id         BIGINT        NULL,                              -- null = COO standard
    template_id    BIGINT        NOT NULL,
    certificate_id BIGINT        NOT NULL,                          -- valid evidence gate
    label_type     NVARCHAR(20)  NOT NULL DEFAULT 'COO',
    lot_no         NVARCHAR(40)  NULL,
    qty            DECIMAL(18,4) NULL,
    origin_country CHAR(2)       NULL,
    status         NVARCHAR(12)  NOT NULL DEFAULT 'issued',        -- issued/reprinted/cancelled
    print_count    INT           NOT NULL DEFAULT 0,
    issued_by      NVARCHAR(50)  NULL,
    issued_at      DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_lbl_serial UNIQUE (serial_no),
    CONSTRAINT FK_lbl_issue_part FOREIGN KEY (part_id)        REFERENCES md_part(part_id),
    CONSTRAINT FK_lbl_issue_oem  FOREIGN KEY (oem_id)         REFERENCES md_oem_customer(oem_id),
    CONSTRAINT FK_lbl_issue_tmpl FOREIGN KEY (template_id)    REFERENCES md_label_template(template_id),
    CONSTRAINT FK_lbl_issue_cert FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT FK_lbl_issue_country FOREIGN KEY (origin_country) REFERENCES md_country(country_code),
    CONSTRAINT CK_lbl_issue_status CHECK (status IN ('issued','reprinted','cancelled'))
);
CREATE INDEX IX_lbl_issue_part ON lbl_issue(part_id);
CREATE INDEX IX_lbl_issue_cert ON lbl_issue(certificate_id);

-- LBL-04 Reprint log
CREATE TABLE lbl_reprint (
    reprint_id    BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    issue_id      BIGINT       NOT NULL,
    reason        NVARCHAR(200) NOT NULL,
    reprinted_by  NVARCHAR(50) NULL,
    reprinted_at  DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_lbl_reprint_issue FOREIGN KEY (issue_id) REFERENCES lbl_issue(issue_id)
);

-- LBL-05 Print job
CREATE TABLE lbl_print_job (
    print_job_id  BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    issue_id      BIGINT       NOT NULL,
    printer       NVARCHAR(40) NULL,
    status        NVARCHAR(12) NOT NULL DEFAULT 'queued',          -- queued/printed/failed
    requested_by  NVARCHAR(50) NULL,
    requested_at  DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    printed_at    DATETIME2    NULL,
    CONSTRAINT FK_lbl_pj_issue FOREIGN KEY (issue_id) REFERENCES lbl_issue(issue_id),
    CONSTRAINT CK_lbl_pj_status CHECK (status IN ('queued','printed','failed'))
);

/* ============================ 4. ORIGIN (ORG) ============================= */

-- ORG-01 Part origin
CREATE TABLE org_part_origin (
    origin_id           BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    part_id             BIGINT       NOT NULL,
    origin_country      CHAR(2)      NOT NULL,
    determination_basis NVARCHAR(20) NOT NULL,                      -- WO/tariff_shift/RVC
    certificate_id      BIGINT       NULL,                          -- supporting evidence (DOC)
    effective_date      DATE         NULL,
    status              NVARCHAR(12) NOT NULL DEFAULT 'pending',   -- pending/confirmed
    created_by          NVARCHAR(50) NULL,
    created_at          DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by          NVARCHAR(50) NULL,
    updated_at          DATETIME2    NULL,
    CONSTRAINT FK_org_po_part    FOREIGN KEY (part_id)        REFERENCES md_part(part_id),
    CONSTRAINT FK_org_po_country FOREIGN KEY (origin_country) REFERENCES md_country(country_code),
    CONSTRAINT FK_org_po_cert    FOREIGN KEY (certificate_id) REFERENCES doc_certificate(certificate_id),
    CONSTRAINT CK_org_po_status  CHECK (status IN ('pending','confirmed'))
);
CREATE INDEX IX_org_po_part ON org_part_origin(part_id);

-- ORG-03 Origin change history (immutable)
CREATE TABLE org_origin_change (
    change_id      BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    part_id        BIGINT       NOT NULL,
    field_changed  NVARCHAR(40) NOT NULL,
    old_value      NVARCHAR(100) NULL,
    new_value      NVARCHAR(100) NULL,
    reason         NVARCHAR(300) NOT NULL,
    certificate_id BIGINT       NULL,
    changed_by     NVARCHAR(50) NULL,
    changed_at     DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_org_oc_part FOREIGN KEY (part_id) REFERENCES md_part(part_id)
);
CREATE INDEX IX_org_oc_part ON org_origin_change(part_id, changed_at);

-- ORG-04 BOM rollup result (finished-good origin)
CREATE TABLE org_rollup_result (
    rollup_id      BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    fg_part_id     BIGINT       NOT NULL,
    result_origin  CHAR(2)      NULL,
    basis          NVARCHAR(40) NULL,
    rvc_estimate   DECIMAL(5,2) NULL,
    status         NVARCHAR(12) NOT NULL DEFAULT 'pending',        -- pending/confirmed
    computed_by    NVARCHAR(50) NULL,
    computed_at    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_org_rr_part    FOREIGN KEY (fg_part_id)    REFERENCES md_part(part_id),
    CONSTRAINT FK_org_rr_country FOREIGN KEY (result_origin) REFERENCES md_country(country_code)
);
CREATE INDEX IX_org_rr_part ON org_rollup_result(fg_part_id);

-- ORG-05 RVC calculation
CREATE TABLE org_rvc_calc (
    rvc_id         BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    fg_part_id     BIGINT        NOT NULL,
    method         NVARCHAR(20)  NOT NULL,                          -- net_cost/transaction_value
    threshold      DECIMAL(5,2)  NULL,
    av             DECIMAL(18,4) NULL,                              -- adjusted value
    vnm            DECIMAL(18,4) NULL,                              -- value of non-originating materials
    rvc_value      DECIMAL(5,2)  NULL,
    result         NVARCHAR(6)   NULL,                              -- pass/fail
    calculated_by  NVARCHAR(50)  NULL,
    calculated_at  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_org_rvc_part FOREIGN KEY (fg_part_id) REFERENCES md_part(part_id),
    CONSTRAINT CK_org_rvc_method CHECK (method IN ('net_cost','transaction_value')),
    CONSTRAINT CK_org_rvc_result CHECK (result IS NULL OR result IN ('pass','fail'))
);
CREATE INDEX IX_org_rvc_part ON org_rvc_calc(fg_part_id);

/* ============================ 5. AUDIT (AUD) ============================== */

-- AUD-03 Generated report
CREATE TABLE aud_report (
    report_id     BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    report_type   NVARCHAR(30)  NOT NULL,                           -- CBP/OEM/internal
    template      NVARCHAR(60)  NULL,
    scope_json    NVARCHAR(MAX) NULL,
    file_path     NVARCHAR(400) NULL,
    hash          NVARCHAR(64)  NULL,                               -- SHA-256, tamper-evident
    status        NVARCHAR(12)  NOT NULL DEFAULT 'generated',
    generated_by  NVARCHAR(50)  NULL,
    generated_at  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- AUD-04 Audit package + items
CREATE TABLE aud_package (
    package_id    BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    package_name  NVARCHAR(100) NOT NULL,
    status        NVARCHAR(12)  NOT NULL DEFAULT 'building',       -- building/validated/exported
    file_path     NVARCHAR(400) NULL,
    hash          NVARCHAR(64)  NULL,
    created_by    NVARCHAR(50)  NULL,
    created_at    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    exported_at   DATETIME2     NULL,
    CONSTRAINT CK_aud_pkg_status CHECK (status IN ('building','validated','exported'))
);

CREATE TABLE aud_package_item (
    item_id     BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    package_id  BIGINT       NOT NULL,
    item_type   NVARCHAR(20) NOT NULL,                              -- certificate/origin/rvc/label/report
    ref_id      BIGINT       NULL,
    valid_flag  BIT          NOT NULL DEFAULT 1,
    CONSTRAINT FK_aud_pi_pkg FOREIGN KEY (package_id) REFERENCES aud_package(package_id) ON DELETE CASCADE
);
CREATE INDEX IX_aud_pi_pkg ON aud_package_item(package_id);

/* ========================= 6. INTEGRATION (INT) =========================== */

CREATE TABLE int_connection (
    connection_id BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    system_name   NVARCHAR(40) NOT NULL,                            -- SAP ECC/S4, SCM
    host          NVARCHAR(120) NULL,
    client_no     NVARCHAR(10) NULL,
    auth_type     NVARCHAR(20) NULL,
    username      NVARCHAR(60) NULL,
    secret_ref    NVARCHAR(100) NULL,                               -- vault reference (masked)
    status        NVARCHAR(12) NOT NULL DEFAULT 'inactive',
    last_test_at  DATETIME2    NULL,
    created_by    NVARCHAR(50) NULL,
    created_at    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE int_endpoint (
    endpoint_id   BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    connection_id BIGINT       NOT NULL,
    object_type   NVARCHAR(20) NOT NULL,                            -- BOM/Supplier/PO
    mode          NVARCHAR(10) NOT NULL DEFAULT 'batch',           -- batch/realtime
    enabled       BIT          NOT NULL DEFAULT 1,
    schedule_cron NVARCHAR(40) NULL,
    last_sync_at  DATETIME2    NULL,
    CONSTRAINT FK_int_ep_conn FOREIGN KEY (connection_id) REFERENCES int_connection(connection_id)
);
CREATE INDEX IX_int_ep_conn ON int_endpoint(connection_id);

CREATE TABLE int_job (
    job_id        BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    endpoint_id   BIGINT       NOT NULL,
    job_type      NVARCHAR(12) NOT NULL,                            -- batch/manual
    started_at    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    finished_at   DATETIME2    NULL,
    added_cnt     INT          NULL,
    changed_cnt   INT          NULL,
    deleted_cnt   INT          NULL,
    conflict_cnt  INT          NULL,
    status        NVARCHAR(12) NOT NULL DEFAULT 'running',          -- running/success/partial/failed
    message       NVARCHAR(400) NULL,
    CONSTRAINT FK_int_job_ep FOREIGN KEY (endpoint_id) REFERENCES int_endpoint(endpoint_id),
    CONSTRAINT CK_int_job_status CHECK (status IN ('running','success','partial','failed'))
);
CREATE INDEX IX_int_job_ep ON int_job(endpoint_id, started_at);

CREATE TABLE int_integrity_issue (
    issue_id     BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    rule_code    NVARCHAR(40) NOT NULL,
    severity     NVARCHAR(10) NOT NULL,                             -- critical/warning/info
    target_type  NVARCHAR(30) NULL,
    target_ref   NVARCHAR(60) NULL,
    detail       NVARCHAR(400) NULL,
    status       NVARCHAR(12) NOT NULL DEFAULT 'open',             -- open/resolved/ignored
    detected_at  DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    resolved_by  NVARCHAR(50) NULL,
    resolved_at  DATETIME2    NULL,
    CONSTRAINT CK_int_issue_sev    CHECK (severity IN ('critical','warning','info')),
    CONSTRAINT CK_int_issue_status CHECK (status IN ('open','resolved','ignored'))
);
CREATE INDEX IX_int_issue_status ON int_integrity_issue(status, severity);

/* ========================= 7. SYSTEM / ADMIN (SYS) ======================== */

CREATE TABLE sys_user (
    user_id       BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    login_id      NVARCHAR(50) NOT NULL,
    user_name     NVARCHAR(50) NOT NULL,
    dept          NVARCHAR(50) NULL,
    email         NVARCHAR(100) NULL,
    status        NVARCHAR(10) NOT NULL DEFAULT 'active',           -- active/locked/inactive
    last_login_at DATETIME2    NULL,
    created_by    NVARCHAR(50) NULL,
    created_at    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_by    NVARCHAR(50) NULL,
    updated_at    DATETIME2    NULL,
    CONSTRAINT UQ_sys_user_login UNIQUE (login_id),
    CONSTRAINT CK_sys_user_status CHECK (status IN ('active','locked','inactive'))
);

CREATE TABLE sys_role (
    role_id     INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    role_code   NVARCHAR(20) NOT NULL,
    role_name   NVARCHAR(50) NOT NULL,
    description NVARCHAR(200) NULL,
    CONSTRAINT UQ_sys_role_code UNIQUE (role_code)
);

CREATE TABLE sys_permission (
    permission_code NVARCHAR(30) NOT NULL PRIMARY KEY,              -- e.g. DOC.View, LBL.Issue
    module          NVARCHAR(10) NOT NULL,
    description     NVARCHAR(200) NULL
);

CREATE TABLE sys_user_role (
    user_id BIGINT NOT NULL,
    role_id INT    NOT NULL,
    CONSTRAINT PK_sys_user_role PRIMARY KEY (user_id, role_id),
    CONSTRAINT FK_sys_ur_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_sys_ur_role FOREIGN KEY (role_id) REFERENCES sys_role(role_id) ON DELETE CASCADE
);

CREATE TABLE sys_role_permission (
    role_id         INT          NOT NULL,
    permission_code NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_sys_role_perm PRIMARY KEY (role_id, permission_code),
    CONSTRAINT FK_sys_rp_role FOREIGN KEY (role_id)         REFERENCES sys_role(role_id) ON DELETE CASCADE,
    CONSTRAINT FK_sys_rp_perm FOREIGN KEY (permission_code) REFERENCES sys_permission(permission_code)
);

-- SYS-02 System/security audit trail (immutable, append-only)
CREATE TABLE sys_audit_log (
    log_id        BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    event_type    NVARCHAR(20) NOT NULL,                            -- login/access/change/view/export
    actor_user_id BIGINT       NULL,
    module        NVARCHAR(10) NULL,
    target        NVARCHAR(100) NULL,
    ip            NVARCHAR(45) NULL,
    result        NVARCHAR(10) NULL,                                -- success/fail
    detail        NVARCHAR(MAX) NULL,
    at            DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_sys_audit_user FOREIGN KEY (actor_user_id) REFERENCES sys_user(user_id)
);
CREATE INDEX IX_sys_audit_at ON sys_audit_log(at);
CREATE INDEX IX_sys_audit_user ON sys_audit_log(actor_user_id);

-- SYS-03 Notification rules + channels
CREATE TABLE sys_notif_channel (
    channel_id   INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    channel_type NVARCHAR(20) NOT NULL,                             -- email/sms/push/messenger
    config_ref   NVARCHAR(100) NULL,                               -- masked secret/config ref
    enabled      BIT          NOT NULL DEFAULT 1
);

CREATE TABLE sys_notif_rule (
    rule_id        INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    event_type     NVARCHAR(30) NOT NULL,                           -- cert_expiry_d30, approval_pending, sync_fail...
    channel_id     INT          NULL,
    recipient_role NVARCHAR(20) NULL,
    retry_count    INT          NOT NULL DEFAULT 3,
    escalation     NVARCHAR(40) NULL,
    enabled        BIT          NOT NULL DEFAULT 1,
    CONSTRAINT FK_sys_nr_channel FOREIGN KEY (channel_id) REFERENCES sys_notif_channel(channel_id)
);

-- SYS-04 Common code (group + items)
CREATE TABLE sys_code_group (
    group_code  NVARCHAR(30) NOT NULL PRIMARY KEY,
    group_name  NVARCHAR(80) NOT NULL,
    description NVARCHAR(200) NULL
);

CREATE TABLE sys_code (
    code_id    BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    group_code NVARCHAR(30) NOT NULL,
    code       NVARCHAR(30) NOT NULL,
    name_ko    NVARCHAR(80) NULL,
    name_en    NVARCHAR(80) NULL,
    sort_order INT          NULL,
    is_active  BIT          NOT NULL DEFAULT 1,
    CONSTRAINT UQ_sys_code UNIQUE (group_code, code),
    CONSTRAINT FK_sys_code_group FOREIGN KEY (group_code) REFERENCES sys_code_group(group_code)
);

/* ============================================================================
   END OF SCHEMA  —  40 tables
   Build order respects FK dependencies; circular refs (md_label_template <->
   md_oem_customer, doc_certificate <-> doc_version) resolved via ALTER ADD.
   ============================================================================ */
