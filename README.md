# Anomaly Detection in Network Traffic
### CICIDS2017 Dataset — EDA, Preprocessing & DWH Design

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Dataset](#2-dataset)
3. [Notebook: EDA & Preprocessing](#3-notebook-eda--preprocessing)
   - [Step 1 — Load & Merge](#step-1--load--merge)
   - [Step 2 — Data Understanding](#step-2--data-understanding)
   - [Step 3 — Temporal Analysis](#step-3--temporal-analysis)
   - [Step 4 — Sparse / Zero-Heavy Column Analysis](#step-4--sparse--zero-heavy-column-analysis)
   - [Step 5 — Feature Distribution Analysis](#step-5--feature-distribution-analysis)
   - [Step 6 — Correlation Analysis](#step-6--correlation-analysis)
   - [Step 7 — Outlier Analysis](#step-7--outlier-analysis)
   - [Step 8 — PCA Visualization](#step-8--pca-visualization)
   - [Step 9 — Preprocessing & Export](#step-9--preprocessing--export)
4. [Key Findings](#4-key-findings)
5. [Exported Files](#5-exported-files)
6. [Next Step: PowerBI Data Warehouse](#6-next-step-powerbi-data-warehouse)
   - [Schema Decision: Star Schema](#schema-decision-star-schema)
   - [Fact Table](#fact-table-fact_network_flow)
   - [Dimension Tables](#dimension-tables)
   - [Relationships](#relationships)
   - [PowerBI Implementation Checklist](#powerbi-implementation-checklist)

---

## 1. Project Overview

This project detects anomalous behavior in network traffic using unsupervised clustering (DBSCAN / GMM). The pipeline has three stages:

| Stage | Status | Deliverable |
|-------|--------|-------------|
| EDA & Preprocessing | ✅ Complete | `CICIDS2017_cleaned_scaled.csv` |
| PowerBI DWH | 🔄 In Progress | Star schema + dashboards |
| Clustering (DBSCAN / GMM) | ⏳ Pending | Cluster labels + alert system |

---

## 2. Dataset

**Source:** [CICIDS2017](https://www.unb.ca/cic/datasets/ids-2017.html) — Canadian Institute for Cybersecurity

**Structure:** 8 daily capture session CSV files, merged into one dataset.

| File | Session Label | Notes |
|------|--------------|-------|
| Monday-WorkingHours.pcap_ISCX.csv | Monday | Benign only (baseline) |
| Tuesday-WorkingHours.pcap_ISCX.csv | Tuesday | Benign + FTP/SSH Brute Force |
| Wednesday-workingHours.pcap_ISCX.csv | Wednesday | Benign + DoS / Heartbleed |
| Thursday-WorkingHours-Morning-WebAttacks.pcap_ISCX.csv | Thursday-Morning | Web Attacks |
| Thursday-WorkingHours-Afternoon-Infilteration.pcap_ISCX.csv | Thursday-Afternoon | Infiltration |
| Friday-WorkingHours-Morning.pcap_ISCX.csv | Friday-Morning | Benign |
| Friday-WorkingHours-Afternoon-PortScan.pcap_ISCX.csv | Friday-PortScan | Port Scan |
| Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv | Friday-DDoS | DDoS |

**Raw shape:** ~2.8M rows × 85 columns (79 numeric features + 6 identifiers/metadata)

---

## 3. Notebook: EDA & Preprocessing

**File:** `CICIDS2017_EDA_Preprocessing.ipynb`

---

### Step 1 — Load & Merge

All 8 CSVs are loaded, column names are stripped of whitespace, and a `capture_session` tag is added to each row before merging into a single DataFrame.

**Output:** Single merged DataFrame (~2.8M rows × 86 columns including `capture_session`).

---

### Step 2 — Data Understanding

- Checked dtypes, shape, and descriptive statistics.
- Detected missing values and `inf` values per column.
- Plotted class distribution as a bar chart and binary pie chart (Benign vs Attack).
- Plotted record count per class per capture session.

**Key output plots:**
- `class_distribution.png` — full label breakdown + binary split pie
- `class_per_session.png` — which sessions contain which attack types

**Finding:** The dataset is heavily imbalanced. BENIGN traffic dominates (~80%+). Attack records are concentrated in specific sessions (Wednesday for DoS, Friday-DDoS for DDoS, etc.).

---

### Step 3 — Temporal Analysis

- Parsed the `Timestamp` column into hour and day.
- Plotted hourly traffic volume (Benign vs Attack stacked) per day.
- Plotted attack type distribution per session (stacked bar).
- Computed and plotted attack rate (%) per session.

**Key output plots:**
- `hourly_traffic.png` — per-day, per-hour breakdown
- `attack_timeline.png` — which attack types appear in each session
- `attack_rate_per_session.png` — aggressiveness of each session

**Finding:** Attack rates vary dramatically by session. Some sessions (e.g., Friday-DDoS) are nearly 100% attack traffic, while Monday is 0% (pure baseline). This temporal dimension is valuable for PowerBI slicing.

---

### Step 4 — Sparse / Zero-Heavy Column Analysis

- Computed zero-value percentage per numeric column.
- Flagged columns that are 100% zero (dropped entirely).
- Flagged near-zero-variance columns (variance < 1e-6, dropped).
- Plotted zero-percentage bar chart with 50% and 90% thresholds.
- Plotted column variance on a log scale.

**Key output plots:**
- `zero_percentage.png`
- `variance_plot.png`

**Finding:** Several columns (bulk rate features, some flag counts) are entirely zero across all records — these carry no information and are dropped. A handful more have near-zero variance.

---

### Step 5 — Feature Distribution Analysis

- Plotted histogram distributions for the top 24 features by variance, overlaid Benign vs Attack.
- Plotted box plots for 8 key traffic features split by attack class (capped at 97th percentile).
- Plotted violin plots for Flow Duration, Fwd/Bwd Packet Length Mean.

**Key output plots:**
- `feature_distributions.png`
- `boxplot_Flow_Duration.png`, `boxplot_Flow_Bytes_s.png`, etc.
- `violin_plots.png`

**Finding:** Several features show strong separation between BENIGN and ATTACK distributions — particularly `Flow Duration`, `Flow Bytes/s`, `Fwd Packet Length Mean`, and `Flow IAT Mean`. These are expected to be high-importance features for the clustering model.

---

### Step 6 — Correlation Analysis

- Computed Pearson correlation matrix on a 50K-row sample for speed.
- Plotted lower-triangle heatmap (top 50 features by variance if >50 features).
- Identified all pairs with |r| > 0.95.
- Built a list of redundant columns to drop.

**Key output plots:**
- `correlation_heatmap.png`

**Finding:** CICIDS2017 has many highly correlated feature groups (e.g., packet length stats, IAT stats). Dropping redundant columns significantly reduces dimensionality without information loss.

---

### Step 7 — Outlier Analysis

- Computed z-scores on a 30K-row sample.
- Plotted outlier percentage (|z| > 3) per feature.
- Scatter plot: `Flow Bytes/s` vs `Flow Duration`, colored by Benign/Attack.
- Scatter plot: Forward vs Backward packet counts, colored by attack class.

**Key output plots:**
- `outlier_analysis.png`
- `scatter_bytes_duration.png`
- `scatter_fwd_bwd.png`

**Finding:** Several features have high outlier rates (>5%). These are not removed — they are meaningful network anomalies (e.g., DDoS flows with extreme `Flow Bytes/s`). The clustering algorithm (especially DBSCAN) is expected to naturally isolate these.

---

### Step 8 — PCA Visualization

- Dropped correlated and zero columns, applied StandardScaler on a 15K sample.
- Projected to 2D using PCA.
- Plotted Benign vs Attack in PCA space.

**Key output plot:**
- `pca_2d.png`

**Finding:** Benign and Attack records show meaningful separation in PCA space, confirming that the feature set carries enough signal for unsupervised clustering to work. The two PCs explain a moderate share of total variance — full variance explained is noted in the plot axis labels.

---

### Step 9 — Preprocessing & Export

The full cleaning pipeline applied in sequence:

| Step | Action | Reason |
|------|--------|--------|
| 1 | Drop 100%-zero columns | No information content |
| 2 | Drop near-zero variance columns (var < 1e-6) | No discriminative power |
| 3 | Replace `inf` → `NaN`, drop `NaN` rows | Model compatibility |
| 4 | Drop duplicate rows | Avoid bias in clustering |
| 5 | Drop highly correlated columns (\|r\| > 0.95) | Reduce redundancy |
| 6 | **Keep** identifier columns (IP, Port, Protocol, Timestamp, capture_session) | Required as DWH dimension keys |
| 7 | Encode labels: `label_multiclass`, `label_binary` (0/1), `label_encoded` (int) | Evaluation after clustering |
| 8 | StandardScaler on numeric feature columns only | Required for distance-based clustering |
| 9 | Export 3 CSVs | See below |

> **Note on Step 6:** Identifier columns are intentionally kept in the export for PowerBI. They are excluded from `feature_cols_final` so they do not enter the scaler.

---

## 4. Key Findings

1. **Heavy class imbalance** — BENIGN dominates (~80%). Clustering must not be biased toward majority-class density. DBSCAN's density threshold `eps` needs careful tuning; GMM needs enough components.

2. **Strong temporal structure** — Attack types are session-specific. `capture_session` and hour-of-day are valuable slice dimensions in the DWH.

3. **High feature redundancy** — Many packet length and IAT statistics are near-perfectly correlated. Post-deduplication, the feature set is significantly smaller.

4. **Extreme outliers are meaningful** — High `Flow Bytes/s` values are real DDoS signatures, not noise. Outlier-preserving algorithms (DBSCAN, GMM) are appropriate.

5. **Good linear separability** — PCA projection shows visible Benign/Attack structure in 2D. Clustering is expected to recover this structure.

---

## 5. Exported Files

| File | Contents | Used For |
|------|----------|----------|
| `CICIDS2017_cleaned_scaled.csv` | Full dataset: scaled features + raw identifiers + labels | PowerBI DWH loading |
| `CICIDS2017_features_only.csv` | Scaled numeric features only (no labels, no identifiers) | Clustering input |
| `CICIDS2017_labels.csv` | `label_binary`, `label_encoded`, `label_multiclass` | Post-clustering evaluation |

---

## 6. Next Step: PowerBI Data Warehouse

### Schema Decision: Star Schema

**Chosen schema: ⭐ Star Schema**

Rationale:
- All dimensions (Time, Protocol, IP, Port, Label) are independent — no hierarchical sub-dimensions that would justify snowflaking.
- PowerBI DAX and DirectQuery perform best on star schemas — fewer joins, faster aggregations.
- The IP and Port dimensions have high cardinality but no meaningful sub-tables (no ASN lookup or VLAN table in scope).
- The team can always snowflake a dimension later if needed (e.g., adding a `Dim_ASN` linked to `Dim_IP`) without redesigning the fact table.

---

### Fact Table: `Fact_Network_Flow`

This is the central table. One row = one network flow.

| Column | Type | Source Column | Notes |
|--------|------|--------------|-------|
| `flow_id` | INT (PK) | Generated | Surrogate primary key — sequential integer |
| `time_key` | INT (FK) | Parsed from `Timestamp` | Links to `Dim_Time` |
| `src_ip_key` | INT (FK) | `Source IP` | Links to `Dim_IP` (source side) |
| `dst_ip_key` | INT (FK) | `Destination IP` | Links to `Dim_IP` (destination side) |
| `src_port_key` | INT (FK) | `Source Port` | Links to `Dim_Port` |
| `dst_port_key` | INT (FK) | `Destination Port` | Links to `Dim_Port` |
| `protocol_key` | INT (FK) | `Protocol` | Links to `Dim_Protocol` |
| `label_key` | INT (FK) | `Label` / `label_encoded` | Links to `Dim_Label` |
| `session_key` | INT (FK) | `capture_session` | Links to `Dim_Session` |
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
| `label_binary` | INT | `label_binary` | 0=Benign, 1=Attack — for quick filtering |
| `cluster_id` | INT | Output of clustering notebook | **Populated in next stage — NULL until clustering runs** |

> All numeric columns above are the **scaled** versions from the preprocessing output. Raw values are not stored in the fact table — use dimension tables or keep the raw CSV separately if needed for explainability.

---

### Dimension Tables

#### `Dim_Time`

Granularity: one row per unique timestamp (or per minute/hour depending on desired grain).

| Column | Type | Notes |
|--------|------|-------|
| `time_key` | INT (PK) | Surrogate key |
| `timestamp_raw` | DATETIME | Original parsed timestamp |
| `date` | DATE | Date only |
| `year` | INT | |
| `month` | INT | 1–12 |
| `day` | INT | Day of month |
| `hour` | INT | 0–23 |
| `minute` | INT | 0–59 |
| `day_of_week` | INT | 0=Monday … 6=Sunday |
| `day_name` | VARCHAR | "Monday", "Tuesday", … |
| `is_weekend` | BIT | 0/1 |
| `time_slot` | VARCHAR | "Morning", "Afternoon", "Evening" — derived from hour |

> **Power Query:** `= Table.AddColumn(Source, "time_slot", each if [hour] < 12 then "Morning" else if [hour] < 17 then "Afternoon" else "Evening")`

---

#### `Dim_IP`

Shared dimension for both source and destination IPs. The fact table links to it twice (`src_ip_key`, `dst_ip_key`).

| Column | Type | Notes |
|--------|------|-------|
| `ip_key` | INT (PK) | Surrogate key |
| `ip_address` | VARCHAR | Raw IP string, e.g. "192.168.1.5" |
| `ip_class` | VARCHAR | "A", "B", "C" — derived from first octet |
| `is_private` | BIT | 1 if RFC1918 range (10.x, 172.16–31.x, 192.168.x) |
| `subnet` | VARCHAR | First 3 octets, e.g. "192.168.1" — for subnet-level grouping |

> **Power Query note:** In PowerBI, create two relationships from `Fact_Network_Flow` to `Dim_IP`: one on `src_ip_key` (active) and one on `dst_ip_key` (inactive). Use `USERELATIONSHIP()` in DAX measures when analysing destination traffic.

---

#### `Dim_Port`

Shared dimension for source and destination ports.

| Column | Type | Notes |
|--------|------|-------|
| `port_key` | INT (PK) | Surrogate key |
| `port_number` | INT | 0–65535 |
| `port_range` | VARCHAR | "Well-Known (0–1023)", "Registered (1024–49151)", "Dynamic (49152–65535)" |
| `common_service` | VARCHAR | "HTTP", "HTTPS", "SSH", "FTP", "DNS", "Unknown" — mapped from well-known ports |
| `is_well_known` | BIT | 1 if port < 1024 |

> **Common service mapping to add in Power Query:**
> - 80 → HTTP, 443 → HTTPS, 22 → SSH, 21 → FTP, 53 → DNS, 3389 → RDP, 23 → Telnet

---

#### `Dim_Protocol`

| Column | Type | Notes |
|--------|------|-------|
| `protocol_key` | INT (PK) | Surrogate key |
| `protocol_number` | INT | Raw value from dataset (6=TCP, 17=UDP, 1=ICMP) |
| `protocol_name` | VARCHAR | "TCP", "UDP", "ICMP", "Other" |

---

#### `Dim_Label`

| Column | Type | Notes |
|--------|------|-------|
| `label_key` | INT (PK) | Surrogate key = `label_encoded` from preprocessing |
| `label_name` | VARCHAR | Full attack name, e.g. "DoS Hulk", "PortScan", "BENIGN" |
| `label_binary` | INT | 0 = Benign, 1 = Attack |
| `attack_category` | VARCHAR | "Benign", "DoS", "Brute Force", "Web Attack", "Scan", "DDoS", "Infiltration", "Botnet" |
| `severity` | VARCHAR | "None", "Low", "Medium", "High" — assign manually based on attack type |

> **Attack category mapping:**
> - BENIGN → Benign
> - DoS Hulk / DoS GoldenEye / DoS slowloris / DoS Slowhttptest / Heartbleed → DoS
> - FTP-Patator / SSH-Patator → Brute Force
> - Web Attack – Brute Force / XSS / SQL Injection → Web Attack
> - PortScan → Scan
> - DDoS → DDoS
> - Infiltration → Infiltration
> - Bot → Botnet

---

#### `Dim_Session`

| Column | Type | Notes |
|--------|------|-------|
| `session_key` | INT (PK) | Surrogate key |
| `session_name` | VARCHAR | "Monday", "Tuesday", "Wednesday", etc. |
| `day_of_week` | INT | |
| `time_of_day` | VARCHAR | "Morning", "Afternoon" — for Thursday/Friday splits |
| `primary_attack` | VARCHAR | Dominant attack type in that session (for annotation) |
| `attack_rate_pct` | FLOAT | Pre-computed from EDA (from `attack_rate_per_session.png`) |

---

### Relationships

```
Fact_Network_Flow
    ├── time_key       → Dim_Time.time_key         (Many-to-One)
    ├── src_ip_key     → Dim_IP.ip_key             (Many-to-One, ACTIVE)
    ├── dst_ip_key     → Dim_IP.ip_key             (Many-to-One, INACTIVE*)
    ├── src_port_key   → Dim_Port.port_key         (Many-to-One, ACTIVE)
    ├── dst_port_key   → Dim_Port.port_key         (Many-to-One, INACTIVE*)
    ├── protocol_key   → Dim_Protocol.protocol_key (Many-to-One)
    ├── label_key      → Dim_Label.label_key       (Many-to-One)
    └── session_key    → Dim_Session.session_key   (Many-to-One)
```

> \* PowerBI only allows one active relationship between two tables. Mark `src_ip_key → Dim_IP` and `src_port_key → Dim_Port` as **active**. Use `USERELATIONSHIP()` in DAX measures for destination-side analysis.

---

### PowerBI Implementation Checklist

**Step 1 — Load data**
- [ ] Import `CICIDS2017_cleaned_scaled.csv` into Power Query
- [ ] Confirm `flow_id` column exists (add in Python if not — see [Exported Files](#5-exported-files))

**Step 2 — Build dimension tables in Power Query**
- [ ] `Dim_Time` — extract from `Timestamp` / `timestamp_parsed` column
- [ ] `Dim_IP` — deduplicate `Source IP` and `Destination IP` combined, assign `ip_key`
- [ ] `Dim_Port` — deduplicate `Source Port` and `Destination Port`, assign `port_key`, map services
- [ ] `Dim_Protocol` — deduplicate `Protocol`, map to name
- [ ] `Dim_Label` — deduplicate `Label`, assign categories and severity
- [ ] `Dim_Session` — deduplicate `capture_session`, enrich manually

**Step 3 — Build fact table**
- [ ] Replace raw identifier columns with their surrogate keys
- [ ] Remove columns already in dimensions from the fact table
- [ ] Keep `label_binary` as a direct column for fast filtering
- [ ] Leave `cluster_id` column as NULL — will be joined in after clustering runs

**Step 4 — Set relationships**
- [ ] Create all relationships as listed above
- [ ] Mark active/inactive for dual IP and dual Port relationships

**Step 5 — Create key DAX measures**
```
Attack Rate % = DIVIDE(CALCULATE(COUNTROWS(Fact_Network_Flow), Dim_Label[label_binary] = 1), COUNTROWS(Fact_Network_Flow))

Avg Flow Duration (ms) = AVERAGE(Fact_Network_Flow[flow_duration]) / 1000

Top Attack Type = FIRSTNONBLANK(TOPN(1, VALUES(Dim_Label[label_name]), CALCULATE(COUNTROWS(Fact_Network_Flow))), 1)
```

**Step 6 — Dashboard pages (suggested)**
- [ ] **Overview** — total flows, attack rate %, top attack types, session breakdown
- [ ] **Temporal** — hourly/daily attack trends, time slicer
- [ ] **Network** — top source/destination IPs, port usage heatmap, protocol split
- [ ] **Anomaly** (post-clustering) — cluster distribution, cluster vs label overlap, flagged flows

---

*README last updated after EDA & Preprocessing stage.*
