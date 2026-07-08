-- Optimizes:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- city is the equality filter and created_at is the range filter, so they are
-- the leading (sorted) columns of a composite B-tree index, in that order.
-- org_id, status, and amount are only ever read (never filtered on) by this
-- query, so they are added as INCLUDE columns rather than key columns: this
-- keeps the index shorter/cheaper to maintain while still letting Postgres
-- satisfy the entire query from the index (index-only scan), without a
-- separate heap fetch per row, as long as the visibility map is up to date.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- booking_events is looked up by booking_id in most workflows (e.g. fetching
-- the event history for a given booking), so index the foreign key.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);
