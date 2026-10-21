---
name: postgres-patterns
description: PostgreSQL database patterns for query optimization, schema design, indexing, and security. Sourced from ECC. Use when designing PostgreSQL schemas, optimizing Django ORM queries, eliminating N+1 queries, creating indexes, or troubleshooting slow database queries.
metadata:
  origin: ECC
  version: "1.0.0"
---

# PostgreSQL Patterns & Query Optimization

Comprehensive PostgreSQL and Django ORM database patterns for BloodPulse to eliminate N+1 queries, accelerate 64-district donor queries, optimize index usage, and ensure efficient pagination.

## When to Activate

- Designing or modifying Django models in `blood_pulse_backend/`.
- Eliminating slow endpoints or N+1 queries in feeds and donor listings.
- Creating PostgreSQL indexes (Composite, Partial, GIN).
- Handling large datasets and pagination.
- Troubleshooting database locking, bloat, or slow queries.

---

## 1. Eliminating N+1 Queries with Django ORM

### The Problem:
Accessing related foreign keys or many-to-many objects inside a loop executes 1 query for the parent list + N queries for each child row.

### The Solution:
- **`select_related`**: For single-valued relationships (`ForeignKey`, `OneToOne`). Uses an SQL `JOIN`.
- **`prefetch_related`**: For multi-valued relationships (`ManyToManyField`, reverse `ForeignKey`). Uses separate queries joined in Python.

```python
# BAD: Executes 1 + N queries (N = number of donation requests)
requests = BloodRequest.objects.all()
for req in requests:
    print(req.requester.profile.phone)  # DB hit per row
    print(req.hospital.name)            # DB hit per row

# GOOD: Executes exactly 1 single optimized SQL JOIN
requests = BloodRequest.objects.select_related(
    'requester__profile',
    'hospital',
).all()

# GOOD: With reverse relationships / tags / responses
requests = BloodRequest.objects.select_related(
    'requester__profile',
    'hospital',
).prefetch_related(
    'donors_responded',
    'comments',
).all()
```

---

## 2. PostgreSQL Index Strategies for BloodPulse

### A. Composite Index for Blood Group & District Search
Donor searches almost always filter by `blood_group` and `district` simultaneously:

```python
# models.py
class DonorProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='donor_profile')
    blood_group = models.CharField(max_length=5, db_index=True)
    district = models.CharField(max_length=64, db_index=True)
    is_available = models.BooleanField(default=True)
    last_donated_at = models.DateField(null=True, blank=True)

    class Meta:
        indexes = [
            # Composite index: equality columns first
            models.Index(
                fields=['blood_group', 'district', 'is_available'],
                name='idx_donor_match',
            ),
        ]
```

### B. Partial Index for Active Blood Requests
Most queries only care about pending/active emergency requests. Avoid indexing millions of archived/completed requests:

```python
class BloodRequest(models.Model):
    patient_name = models.CharField(max_length=120)
    blood_group = models.CharField(max_length=5)
    district = models.CharField(max_length=64)
    status = models.CharField(max_length=20, default='ACTIVE')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            # Partial index: only indexes active records, keeping index size tiny and fast
            models.Index(
                fields=['district', 'blood_group', '-created_at'],
                name='idx_active_blood_requests',
                condition=models.Q(status='ACTIVE'),
            ),
        ]
```

### C. GIN Index for Full-Text Search
For searching hospital names, doctor notes, or community descriptions in Bengali/English:

```python
from django.contrib.postgres.indexes import GinIndex

class Hospital(models.Model):
    name = models.CharField(max_length=255)
    address = models.TextField()

    class Meta:
        indexes = [
            GinIndex(fields=['name'], name='gin_hospital_name', opclasses=['gin_trgm_ops']),
        ]
```

---

## 3. Cursor Pagination vs Deep OFFSET

### Problem with `OFFSET`:
`OFFSET 10000 LIMIT 20` scans 10,020 rows and discards the first 10,000, causing severe database degradation as feeds grow.

### Solution with Keyset / Cursor Pagination:

```python
# In DRF settings or ViewSet:
from rest_framework.pagination import CursorPagination

class FeedCursorPagination(CursorPagination):
    page_size = 20
    ordering = '-created_at'  # Must be indexed!
```

---

## 4. Query Diagnostic Checklist

- [ ] Are all foreign keys indexed?
- [ ] Have all loops iterating over model relations used `select_related` or `prefetch_related`?
- [ ] Are composite indexes ordered with high-cardinality equality fields first, range fields last?
- [ ] Are soft-deleted or archived rows excluded using partial indexes?
- [ ] Has `EXPLAIN ANALYZE` been run on critical search endpoints to ensure `Index Scan` rather than `Seq Scan`?
