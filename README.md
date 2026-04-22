# Anomaly Detection in Network Traffic

**Dataset:** CICIDS2017 — Canadian Institute for Cybersecurity
**Goal:** Detect anomalous network flows using unsupervised clustering (DBSCAN / GMM), backed by a PowerBI data warehouse for exploration and alerting.

---

## Pipeline Stages

| Stage | Status | Deliverable |
|-------|--------|-------------|
| EDA & Preprocessing | ✅ Complete | `CICIDS2017_cleaned_scaled.csv` |
| PowerBI Data Warehouse | In Progress | Star schema + dashboards |
| Clustering (DBSCAN / GMM) | Pending | Cluster labels + alert system |

---

## Repository Structure

```
.
├── README.md                          ← You are here
├── DATA_README.md                     ← Dataset details, schema, EDA findings
├── CICIDS2017_EDA_Preprocessing.ipynb ← Full EDA and preprocessing notebook
└── data/
    ├── CICIDS2017_cleaned_scaled.csv  ← Full dataset: scaled features + identifiers + labels
    ├── CICIDS2017_features_only.csv   ← Scaled numeric features only (clustering input)
    └── CICIDS2017_labels.csv          ← Ground-truth labels for post-clustering evaluation
```

---

## Stage 1 — EDA & Preprocessing

The preprocessing notebook (`CICIDS2017_EDA_Preprocessing.ipynb`) performs the following steps in sequence:

| Step | Action | Reason |
|------|--------|--------|
| 1 | Drop 100%-zero columns | No information content |
| 2 | Drop near-zero variance columns (var < 1e-6) | No discriminative power |
| 3 | Replace `inf` → `NaN`, drop `NaN` rows | Model compatibility |
| 4 | Drop duplicate rows | Avoid bias in clustering |
| 5 | Drop highly correlated columns (\|r\| > 0.95) | Reduce redundancy |
| 6 | Retain identifier columns (IP, Port, Protocol, Timestamp, session) | Required as DWH dimension keys |
| 7 | Encode labels: `label_multiclass`, `label_binary`, `label_encoded` | Post-clustering evaluation |
| 8 | StandardScaler on numeric feature columns only | Required for distance-based clustering |
| 9 | Export three CSVs | See above |

See [`DATA_README.md`](./DATA_README.md) for full EDA findings, key feature insights, and the complete DWH schema.

---

## Stage 2 — PowerBI Data Warehouse

Schema: **Star Schema** — one central fact table (`Fact_Network_Flow`) linked to six dimension tables.

Dimensions: `Dim_Time`, `Dim_IP`, `Dim_Port`, `Dim_Protocol`, `Dim_Label`, `Dim_Session`.

Dashboard pages planned:

- **Overview** — total flows, attack rate %, top attack types, session breakdown
- **Temporal** — hourly/daily attack trends with time slicer
- **Network** — top source/destination IPs, port usage heatmap, protocol split
- **Anomaly** *(post-clustering)* — cluster distribution, cluster vs. label overlap, flagged flows

Full schema specification and PowerBI implementation checklist are in [`DATA_README.md`](./DATA_README.md).

---

## Stage 3 — Clustering (Pending)

Two unsupervised algorithms will be evaluated:

- **DBSCAN** — density-based; naturally isolates extreme outliers (e.g. DDoS flows with extreme `Flow Bytes/s`); requires careful tuning of `eps` given class imbalance.
- **GMM** — probabilistic; soft cluster assignments; needs enough components to avoid collapsing on the BENIGN majority.

Cluster labels (`cluster_id`) will be joined back into `Fact_Network_Flow` after this stage runs. The column is currently `NULL` in the DWH.

---

## Key Findings (from EDA)

1. **Heavy class imbalance** — BENIGN traffic accounts for ~80%+ of all flows. Clustering parameters must not be biased toward majority-class density.
2. **Strong temporal structure** — Attack types are session-specific. `capture_session` and hour-of-day are high-value slice dimensions.
3. **High feature redundancy** — Packet length and IAT statistics are near-perfectly correlated in groups. Post-deduplication the feature set is significantly smaller.
4. **Outliers are meaningful** — Extreme `Flow Bytes/s` values are real DDoS signatures. They are preserved intentionally.
5. **Good linear separability** — PCA projection in 2D shows visible Benign/Attack structure, confirming the feature set carries sufficient signal for unsupervised separation.

---

*README last updated after EDA & Preprocessing stage.*