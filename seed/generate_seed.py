#!/usr/bin/env python3
"""
Generates seed/001_seed_data.sql with deterministic-but-varied sample data:
  - 120 hotel_bookings rows across 5 cities, 4 orgs, 4 statuses
  - booking_events for roughly half of the bookings

Run this to regenerate the seed file:
    python3 seed/generate_seed.py > seed/001_seed_data.sql
"""
import random
import uuid
from datetime import datetime, timedelta

random.seed(42)  # deterministic output across runs

CITIES = ["delhi", "mumbai", "bengaluru", "chennai", "hyderabad"]
STATUSES = ["confirmed", "cancelled", "completed", "pending"]
ORG_IDS = [str(uuid.uuid4()) for _ in range(4)]
HOTELS = [f"hotel-{i:03d}" for i in range(1, 21)]
EVENT_TYPES = ["created", "payment_received", "checked_in", "checked_out", "cancelled"]

NUM_BOOKINGS = 120
NOW = datetime.utcnow()

lines = []
lines.append("-- Auto-generated seed data. Do not hand-edit; rerun generate_seed.py instead.")
lines.append("BEGIN;")
lines.append("")

booking_ids = []

lines.append("INSERT INTO hotel_bookings "
             "(id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at) VALUES")

booking_rows = []
for i in range(NUM_BOOKINGS):
    b_id = str(uuid.uuid4())
    booking_ids.append(b_id)

    org_id = random.choice(ORG_IDS)
    hotel_id = random.choice(HOTELS)
    city = random.choice(CITIES)

    # Spread created_at across the last 90 days so the "last 30 days" filter
    # in the target query returns a realistic subset, not everything.
    days_ago = random.randint(0, 90)
    created_at = NOW - timedelta(days=days_ago, hours=random.randint(0, 23))

    checkin = created_at.date() + timedelta(days=random.randint(1, 30))
    checkout = checkin + timedelta(days=random.randint(1, 7))

    amount = round(random.uniform(1500, 25000), 2)
    status = random.choice(STATUSES)

    booking_rows.append(
        f"  ('{b_id}', '{org_id}', '{hotel_id}', '{city}', "
        f"'{checkin}', '{checkout}', {amount}, '{status}', '{created_at.isoformat()}')"
    )

lines.append(",\n".join(booking_rows) + ";")
lines.append("")

# Booking events for ~half the bookings, 1-3 events each
lines.append("INSERT INTO booking_events (booking_id, event_type, payload, created_at) VALUES")
event_rows = []
for b_id in random.sample(booking_ids, k=NUM_BOOKINGS // 2):
    for _ in range(random.randint(1, 3)):
        event_type = random.choice(EVENT_TYPES)
        created_at = NOW - timedelta(days=random.randint(0, 90), hours=random.randint(0, 23))
        payload = '{"source": "seed-script"}'
        event_rows.append(
            f"  ('{b_id}', '{event_type}', '{payload}'::jsonb, '{created_at.isoformat()}')"
        )

lines.append(",\n".join(event_rows) + ";")
lines.append("")
lines.append("COMMIT;")

print("\n".join(lines))
