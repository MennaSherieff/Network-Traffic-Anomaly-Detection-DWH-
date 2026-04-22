# DATA_README — CICIDS2017 Dataset

Dataset documentation, EDA walkthrough, exported file descriptions, and PowerBI data warehouse schema.

---

## Table of Contents

1. [Dataset Overview](#1-dataset-overview)
2. [EDA & Preprocessing Notebook](#2-eda--preprocessing-notebook)
3. [Key Findings](#3-key-findings)
4. [Exported Files](#4-exported-files)
5. [PowerBI Data Warehouse](#5-powerbi-data-warehouse)

---

## 1. Dataset Overview

**Source:** [CICIDS2017](https://www.unb.ca/cic/datasets/ids-2017.html) — Canadian Institute for Cybersecurity

**Raw shape:** ~2.8M rows × 85 columns (79 numeric features + 6 identifier/metadata columns)

**Structure:** 8 daily capture session CSV files, merged into a single dataset.

| File | Session Label | Attack Types |
|------|--------------|--------------|
| Monday-WorkingHours.pcap_ISCX.csv | Monday | Benign only (baseline) |
| Tuesday-WorkingHours.pcap_ISCX.csv | Tuesday | FTP Brute Force, SSH Brute Force |
| Wednesday-workingHours.pcap_ISCX.csv | Wednesday | DoS variants, Heartbleed |
| Thursday-WorkingHours-Morning-WebAttacks.pcap_ISCX.csv | Thursday-Morning | Web Attacks (SQLi, XSS, Brute Force) |
| Thursday-WorkingHours-Afternoon-Infilteration.pcap_ISCX.csv | Thursday-Afternoon | Infiltration |
| Friday-WorkingHours-Morning.pcap_ISCX.csv | Friday-Morning | Benign |
| Friday-WorkingHours-Afternoon-PortScan.pcap_ISCX.csv | Friday-PortScan | Port Scan |
| Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv | Friday-DDoS | DDoS |

---

## 2. EDA & Preprocessing Notebook

**File:** `CICIDS2017_EDA_Preprocessing.ipynb`

---

### Step 1 — Load & Merge

All 8 CSVs are loaded, column names are stripped of whitespace, and a `capture_session` tag is added to each row before merging into a single DataFrame.

**Output:** Single DataFrame (~2.8M rows × 86 columns including `capture_session`).

---

### Step 2 — Data Understanding

Checked dtypes, shape, and descriptive statistics. Detected missing and `inf` values per column. Plotted full class distribution (bar chart) and binary Benign vs. Attack split (pie chart). Plotted record count per class per capture session.

**Output plots:**
- `class_distribution.png` — full label breakdown + binary split pie
- `class_per_session.png` — attack types per session

**Finding:** The dataset is heavily imbalanced. BENIGN traffic dominates (~80%+). Attack records are concentrated in specific sessions (Wednesday for DoS, Friday-DDoS for DDoS, etc.).

---

### Step 3 — Temporal Analysis

Parsed the `Timestamp` column into hour and day. Plotted hourly traffic volume (Benign vs. Attack stacked) per day, attack type distribution per session, and attack rate (%) per session.

**Output plots:**
- `hourly_traffic.png` — per-day, per-hour breakdown
- `attack_timeline.png` — attack types per session
- `attack_rate_per_session.png` — session aggressiveness

**Finding:** Attack rates vary dramatically by session. Friday-DDoS is nearly 100% attack traffic; Monday is 0% (pure baseline). This temporal dimension is valuable for PowerBI slicing.

---

### Step 4 — Sparse / Zero-Heavy Column Analysis

Computed zero-value percentage per column. Flagged 100%-zero columns (dropped) and near-zero variance columns (var < 1e-6, dropped). Plotted zero-percentage distribution with 50% and 90% thresholds and column variance on a log scale.

**Output plots:**
- `zero_percentage.png`
- `variance_plot.png`

**Finding:** Several bulk-rate feature columns and flag count columns are entirely zero across all records. A handful more have near-zero variance. All are dropped.

---

### Step 5 — Feature Distribution Analysis

Plotted histogram distributions for the top 24 features by variance (Benign vs. Attack overlaid). Plotted box plots for 8 key traffic features split by attack class (capped at 97th percentile). Plotted violin plots for Flow Duration and Fwd/Bwd Packet Length Mean.

**Output plots:**
- `feature_distributions.png`
- `boxplot_Flow_Duration.png`, `boxplot_Flow_Bytes_s.png`, etc.
- `violin_plots.png`

**Finding:** `Flow Duration`, `Flow Bytes/s`, `Fwd Packet Length Mean`, and `Flow IAT Mean` show the strongest separation between BENIGN and ATTACK distributions. These are expected to be the highest-importance features for clustering.

---

### Step 6 — Correlation Analysis

Computed Pearson correlation matrix on a 50K-row sample. Plotted lower-triangle heatmap (top 50 features by variance). Identified all pairs with |r| > 0.95 and built a redundant column drop list.

**Output plot:** `correlation_heatmap.png`

**Finding:** Many packet length and IAT statistics are near-perfectly correlated. Dropping redundant columns significantly reduces dimensionality without information loss.

---

### Step 7 — Outlier Analysis

Computed z-scores on a 30K-row sample. Plotted outlier percentage (|z| > 3) per feature. Produced scatter plots of `Flow Bytes/s` vs. `Flow Duration` and forward vs. backward packet counts, both colored by attack class.

**Output plots:**
- `outlier_analysis.png`
- `scatter_bytes_duration.png`
- `scatter_fwd_bwd.png`

**Finding:** Several features have high outlier rates (>5%). These are not removed — extreme `Flow Bytes/s` values are real DDoS signatures. DBSCAN and GMM are both outlier-preserving by design.

---

### Step 8 — PCA Visualization

Dropped correlated and zero columns, applied StandardScaler on a 15K-row sample, and projected to 2D using PCA. Plotted Benign vs. Attack in PCA space.

**Output plot:** `pca_2d.png`

**Finding:** Benign and Attack records show meaningful separation in PCA space, confirming that the feature set carries enough signal for unsupervised clustering to recover the underlying structure.

---

### Step 9 — Preprocessing & Export

| Step | Action | Reason |
|------|--------|--------|
| 1 | Drop 100%-zero columns | No information content |
| 2 | Drop near-zero variance columns (var < 1e-6) | No discriminative power |
| 3 | Replace `inf` → `NaN`, drop `NaN` rows | Model compatibility |
| 4 | Drop duplicate rows | Avoid bias in clustering |
| 5 | Drop highly correlated columns (\|r\| > 0.95) | Reduce redundancy |
| 6 | **Retain** identifier columns (IP, Port, Protocol, Timestamp, capture_session) | Required as DWH dimension keys |
| 7 | Encode labels: `label_multiclass`, `label_binary` (0/1), `label_encoded` (int) | Post-clustering evaluation |
| 8 | StandardScaler on numeric feature columns only | Required for distance-based clustering |
| 9 | Export 3 CSVs | See Section 4 |

> Identifier columns are intentionally kept in the export for PowerBI. They are excluded from `feature_cols_final` so they do not pass through the scaler.

---

## 3. Key Findings

1. **Heavy class imbalance** — BENIGN dominates (~80%). DBSCAN's `eps` threshold needs careful tuning; GMM needs enough components to avoid collapsing on the majority class.

2. **Strong temporal structure** — Attack types are session-specific. `capture_session` and hour-of-day are high-value slice dimensions in the DWH.

3. **High feature redundancy** — Packet length and IAT statistics are near-perfectly correlated in groups. The post-deduplication feature set is significantly smaller.

4. **Outliers are meaningful** — Extreme `Flow Bytes/s` values are genuine DDoS signatures. They are preserved and expected to be isolated naturally by both clustering algorithms.

5. **Good linear separability** — PCA projection shows visible Benign/Attack structure in 2D. Clustering is expected to recover this separation without supervision.

---

## 4. Exported Files

| File | Contents | Used For |
|------|----------|----------|
| `CICIDS2017_cleaned_scaled.csv` | Full dataset: scaled features + raw identifiers + labels | PowerBI DWH loading |
| `CICIDS2017_features_only.csv` | Scaled numeric features only (no labels, no identifiers) | Clustering input |
| `CICIDS2017_labels.csv` | `label_binary`, `label_encoded`, `label_multiclass` | Post-clustering evaluation |

---

## 5. PowerBI Data Warehouse

### Schema Decision: Star Schema

**Rationale:**

All dimensions (Time, Protocol, IP, Port, Label, Session) are independent with no meaningful sub-hierarchies that would justify snowflaking. PowerBI DAX and DirectQuery perform best on star schemas due to fewer joins and faster aggregations. The IP and Port dimensions have high cardinality but no sub-tables in scope (no ASN lookup or VLAN table). A dimension can always be snowflaked later (e.g. adding `Dim_ASN` linked to `Dim_IP`) without touching the fact table.

---

### Fact Table: `Fact_Network_Flow`

One row = one network flow.

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `flow_id` | INT (PK) | Generated | Surrogate primary key — sequential integer |
| `time_key` | INT (FK) | `Timestamp` | → `Dim_Time` |
| `src_ip_key` | INT (FK) | `Source IP` | → `Dim_IP` (active relationship) |
| `dst_ip_key` | INT (FK) | `Destination IP` | → `Dim_IP` (inactive — use `USERELATIONSHIP()`) |
| `src_port_key` | INT (FK) | `Source Port` | → `Dim_Port` (active relationship) |
| `dst_port_key` | INT (FK) | `Destination Port` | → `Dim_Port` (inactive — use `USERELATIONSHIP()`) |
| `protocol_key` | INT (FK) | `Protocol` | → `Dim_Protocol` |
| `label_key` | INT (FK) | `Label` / `label_encoded` | → `Dim_Label` |
| `session_key` | INT (FK) | `capture_session` | → `Dim_Session` |
| `flow_duration` | FLOAT | `Flow Duration` | Microseconds |
| `total_fwd_packets` | INT | `Total Fwd Packets` | |
| `total_bwd_packets` | INT | `Total Backward Packets` | |
| `total_len_fwd_pkts` | FLOAT | `Total Length of Fwd Packets` | |
| `total_len_bwd_pkts` | FLOAT | `Total Length of Bwd Packets` | |
| `fwd_pkt_len_mean` | FLOAT | `Fwd Packet Length Mean` | |
| `fwd_pkt_len_std` | FLOAT | `Fwd Packet Length Std` | |
| `bwd_pkt_len_mean` | FLOAT | `Bwd Packet Length Mean` | |
| `bwd_pkt_len_std` | FLOAT | `Bwd Packet Length Std` | |
| `flow_bytes_per_s` | FLOAT | `Flow Bytes/s` | Key anomaly indicator |
| `flow_pkts_per_s` | FLOAT | `Flow Packets/s` | Key anomaly indicator |
| `flow_iat_mean` | FLOAT | `Flow IAT Mean` | Inter-arrival time |
| `flow_iat_std` | FLOAT | `Flow IAT Std` | |
| `flow_iat_max` | FLOAT | `Flow IAT Max` | |
| `fwd_iat_total` | FLOAT | `Fwd IAT Total` | |
| `bwd_iat_total` | FLOAT | `Bwd IAT Total` | |
| `syn_flag_count` | INT | `SYN Flag Count` | |
| `fin_flag_count` | INT | `FIN Flag Count` | |
| `rst_flag_count` | INT | `RST Flag Count` | |
| `psh_flag_count` | INT | `PSH Flag Count` | |
| `ack_flag_count` | INT | `ACK Flag Count` | |
| `pkt_len_mean` | FLOAT | `Packet Length Mean` | |
| `pkt_len_variance` | FLOAT | `Packet Length Variance` | |
| `avg_pkt_size` | FLOAT | `Average Packet Size` | |
| `down_up_ratio` | FLOAT | `Down/Up Ratio` | |
| `init_win_fwd` | INT | `Init_Win_bytes_forward` | TCP window size |
| `init_win_bwd` | INT | `Init_Win_bytes_backward` | |
| `active_mean` | FLOAT | `Active Mean` | |
| `idle_mean` | FLOAT | `Idle Mean` | |
| `label_binary` | INT | `label_binary` | 0 = Benign, 1 = Attack — for fast filtering |
| `cluster_id` | INT | Clustering notebook output | **NULL until Stage 3 runs** |

> All numeric columns store **scaled** values from the preprocessing output. Raw values are not stored in the fact table — retain the original CSV separately if raw values are needed for explainability.

---

### Dimension Tables

#### `Dim_Time`

Granularity: one row per unique timestamp (or per minute/hour depending on desired grain).

| Column | Type | Notes |
|--------|------|-------|
| `time_key` | INT (PK) | Surrogate key |
| `timestamp_raw` | DATETIME | Original parsed timestamp |
| `date` | DATE | |
| `year` | INT | |
| `month` | INT | 1–12 |
| `day` | INT | Day of month |
| `hour` | INT | 0–23 |
| `minute` | INT | 0–59 |
| `day_of_week` | INT | 0 = Monday … 6 = Sunday |
| `day_name` | VARCHAR | "Monday", "Tuesday", … |
| `is_weekend` | BIT | 0/1 |
| `time_slot` | VARCHAR | "Morning" / "Afternoon" / "Evening" — derived from hour |

Power Query formula for `time_slot`:
```
= Table.AddColumn(Source, "time_slot", each if [hour] < 12 then "Morning" else if [hour] < 17 then "Afternoon" else "Evening")
```

---

#### `Dim_IP`

Shared dimension for both source and destination IPs. The fact table links to it twice via `src_ip_key` (active) and `dst_ip_key` (inactive).

| Column | Type | Notes |
|--------|------|-------|
| `ip_key` | INT (PK) | Surrogate key |
| `ip_address` | VARCHAR | Raw IP string, e.g. "192.168.1.5" |
| `ip_class` | VARCHAR | "A", "B", "C" — derived from first octet |
| `is_private` | BIT | 1 if RFC1918 range (10.x, 172.16–31.x, 192.168.x) |
| `subnet` | VARCHAR | First 3 octets, e.g. "192.168.1" — for subnet-level grouping |

> In PowerBI, mark `src_ip_key → Dim_IP` as the **active** relationship. Use `USERELATIONSHIP()` in DAX measures when analysing destination traffic.

---

#### `Dim_Port`

Shared dimension for source and destination ports.

| Column | Type | Notes |
|--------|------|-------|
| `port_key` | INT (PK) | Surrogate key |
| `port_number` | INT | 0–65535 |
| `port_range` | VARCHAR | "Well-Known (0–1023)", "Registered (1024–49151)", "Dynamic (49152–65535)" |
| `common_service` | VARCHAR | "HTTP", "HTTPS", "SSH", "FTP", "DNS", "Unknown" |
| `is_well_known` | BIT | 1 if port < 1024 |

Common service mappings: 80 → HTTP, 443 → HTTPS, 22 → SSH, 21 → FTP, 53 → DNS, 3389 → RDP, 23 → Telnet.

---

#### `Dim_Protocol`

| Column | Type | Notes |
|--------|------|-------|
| `protocol_key` | INT (PK) | Surrogate key |
| `protocol_number` | INT | Raw value (6 = TCP, 17 = UDP, 1 = ICMP) |
| `protocol_name` | VARCHAR | "TCP", "UDP", "ICMP", "Other" |

---

#### `Dim_Label`

| Column | Type | Notes |
|--------|------|-------|
| `label_key` | INT (PK) | = `label_encoded` from preprocessing |
| `label_name` | VARCHAR | Full attack name, e.g. "DoS Hulk", "PortScan", "BENIGN" |
| `label_binary` | INT | 0 = Benign, 1 = Attack |
| `attack_category` | VARCHAR | "Benign", "DoS", "Brute Force", "Web Attack", "Scan", "DDoS", "Infiltration", "Botnet" |
| `severity` | VARCHAR | "None", "Low", "Medium", "High" — assigned manually |

Attack category mapping:

| Label | Category |
|-------|----------|
| BENIGN | Benign |
| DoS Hulk / GoldenEye / slowloris / Slowhttptest / Heartbleed | DoS |
| FTP-Patator / SSH-Patator | Brute Force |
| Web Attack – Brute Force / XSS / SQL Injection | Web Attack |
| PortScan | Scan |
| DDoS | DDoS |
| Infiltration | Infiltration |
| Bot | Botnet |

---

#### `Dim_Session`

| Column | Type | Notes |
|--------|------|-------|
| `session_key` | INT (PK) | Surrogate key |
| `session_name` | VARCHAR | "Monday", "Tuesday", "Wednesday", etc. |
| `day_of_week` | INT | |
| `time_of_day` | VARCHAR | "Morning" / "Afternoon" — for Thursday/Friday splits |
| `primary_attack` | VARCHAR | Dominant attack type in that session |
| `attack_rate_pct` | FLOAT | Pre-computed from EDA |

---

### Relationships

```
Fact_Network_Flow
    ├── time_key       → Dim_Time.time_key          (Many-to-One)
    ├── src_ip_key     → Dim_IP.ip_key              (Many-to-One, ACTIVE)
    ├── dst_ip_key     → Dim_IP.ip_key              (Many-to-One, INACTIVE *)
    ├── src_port_key   → Dim_Port.port_key          (Many-to-One, ACTIVE)
    ├── dst_port_key   → Dim_Port.port_key          (Many-to-One, INACTIVE *)
    ├── protocol_key   → Dim_Protocol.protocol_key  (Many-to-One)
    ├── label_key      → Dim_Label.label_key        (Many-to-One)
    └── session_key    → Dim_Session.session_key    (Many-to-One)
```

> \* PowerBI allows only one active relationship between two tables. Use `USERELATIONSHIP()` in DAX measures for destination-side analysis.

---

### PowerBI Implementation Checklist

**Step 1 — Load data**
- [ ] Import `CICIDS2017_cleaned_scaled.csv` into Power Query
- [ ] Confirm `flow_id` column exists (add in Python if missing before import)

**Step 2 — Build dimension tables in Power Query**
- [ ] `Dim_Time` — extract from `Timestamp` / `timestamp_parsed`
- [ ] `Dim_IP` — deduplicate union of `Source IP` and `Destination IP`, assign `ip_key`
- [ ] `Dim_Port` — deduplicate union of `Source Port` and `Destination Port`, assign `port_key`, map services
- [ ] `Dim_Protocol` — deduplicate `Protocol`, map to name
- [ ] `Dim_Label` — deduplicate `Label`, assign categories and severity manually
- [ ] `Dim_Session` — deduplicate `capture_session`, enrich manually

**Step 3 — Build fact table**
- [ ] Replace raw identifier columns with surrogate keys
- [ ] Remove columns already stored in dimension tables
- [ ] Retain `label_binary` as a direct column for fast filtering
- [ ] Leave `cluster_id` as NULL — will be populated after Stage 3

**Step 4 — Set relationships**
- [ ] Create all relationships as listed above
- [ ] Mark active / inactive for the dual IP and dual Port relationships

**Step 5 — Key DAX measures**

```dax
Attack Rate % =
    DIVIDE(
        CALCULATE(COUNTROWS(Fact_Network_Flow), Dim_Label[label_binary] = 1),
        COUNTROWS(Fact_Network_Flow)
    )

Avg Flow Duration (ms) =
    AVERAGE(Fact_Network_Flow[flow_duration]) / 1000

Top Attack Type =
    FIRSTNONBLANK(
        TOPN(1, VALUES(Dim_Label[label_name]),
            CALCULATE(COUNTROWS(Fact_Network_Flow))),
        1
    )
```

**Step 6 — Dashboard pages**
- [ ] **Overview** — total flows, attack rate %, top attack types, session breakdown
- [ ] **Temporal** — hourly/daily attack trends, time slicer
- [ ] **Network** — top source/destination IPs, port usage heatmap, protocol split
- [ ] **Anomaly** *(post-clustering)* — cluster distribution, cluster vs. label overlap, flagged flows

---

*DATA_README last updated after EDA & Preprocessing stage.*
