# Gender Preference SQL Filter Examples

## How the Filtering Works

When a customer selects a gender preference, the backend modifies the SQL queries used to find eligible providers for on-demand bookings.

## Example Queries

### Without Gender Preference (No Preference)
```sql
SELECT sp.serviceproviderid, sp.latitude, sp.longitude, sp.gender
FROM serviceprovider sp
WHERE sp.isactive = true
  AND sp.latitude IS NOT NULL
  AND sp.longitude IS NOT NULL
  AND sp.housekeepingrole = 'MAID'  -- or 'COOK'
  -- Distance calculation...
  AND (distance_calculation) <= 30  -- radius in km
  -- Availability checks...
```

**Result:** All active providers within radius are considered.

---

### With Male Preference
```sql
SELECT sp.serviceproviderid, sp.latitude, sp.longitude, sp.gender
FROM serviceprovider sp
WHERE sp.isactive = true
  AND sp.latitude IS NOT NULL
  AND sp.longitude IS NOT NULL
  AND sp.housekeepingrole = 'MAID'  -- or 'COOK'
  AND UPPER(TRIM(COALESCE(sp.gender, ''))) = UPPER('Male')  -- ✨ Gender filter added
  -- Distance calculation...
  AND (distance_calculation) <= 30  -- radius in km
  -- Availability checks...
```

**Result:** Only male providers within radius are considered.

---

### With Female Preference
```sql
SELECT sp.serviceproviderid, sp.latitude, sp.longitude, sp.gender
FROM serviceprovider sp
WHERE sp.isactive = true
  AND sp.latitude IS NOT NULL
  AND sp.longitude IS NOT NULL
  AND sp.housekeepingrole = 'MAID'  -- or 'COOK'
  AND UPPER(TRIM(COALESCE(sp.gender, ''))) = UPPER('Female')  -- ✨ Gender filter added
  -- Distance calculation...
  AND (distance_calculation) <= 30  -- radius in km
  -- Availability checks...
```

**Result:** Only female providers within radius are considered.

---

## Implementation Details

### Dynamic SQL Construction

The gender filter is added conditionally:

```javascript
const genderFilterSql = genderPreference && genderPreference !== 'No Preference'
  ? `AND UPPER(TRIM(COALESCE(sp.gender, ''))) = UPPER($10)`
  : '';
```

- **Case-insensitive:** Uses `UPPER()` to handle 'male', 'Male', 'MALE', etc.
- **Whitespace safe:** `TRIM()` removes leading/trailing spaces
- **Null safe:** `COALESCE(sp.gender, '')` handles NULL gender values
- **Parameterized:** Uses `$10` placeholder to prevent SQL injection

### Parameter Array

```javascript
const queryParams = [
  coords.lat,        // $1
  coords.lng,        // $2
  role,              // $3
  radiusKm,          // $4
  visitDate,         // $5
  dayWindowStart,    // $6
  dayWindowEnd,      // $7
  startEpoch,        // $8
  endEpoch,          // $9
];

// Add gender parameter only if preference is specified
if (genderPreference && genderPreference !== 'No Preference') {
  queryParams.push(genderPreference);  // $10
}
```

---

## Testing Queries

### Check Provider Gender Distribution
```sql
SELECT 
  housekeepingrole,
  gender,
  COUNT(*) as count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM serviceprovider
WHERE isactive = true
GROUP BY housekeepingrole, gender
ORDER BY housekeepingrole, count DESC;
```

### Find Providers That Would Be Filtered
```sql
-- All MAID providers within 30km of a location
WITH nearby_providers AS (
  SELECT 
    serviceproviderid,
    firstname,
    lastname,
    gender,
    latitude,
    longitude,
    (
      6371 * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians(12.9716)) * cos(radians(latitude)) *
          cos(radians(longitude) - radians(77.5946)) +
          sin(radians(12.9716)) * sin(radians(latitude))
        ))
      )
    ) AS distance_km
  FROM serviceprovider
  WHERE isactive = true
    AND housekeepingrole = 'MAID'
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL
)
SELECT 
  gender,
  COUNT(*) as provider_count,
  ROUND(AVG(distance_km)::numeric, 2) as avg_distance_km,
  ROUND(MIN(distance_km)::numeric, 2) as min_distance_km,
  ROUND(MAX(distance_km)::numeric, 2) as max_distance_km
FROM nearby_providers
WHERE distance_km <= 30
GROUP BY gender
ORDER BY provider_count DESC;
```

### Verify Gender Preference in Engagements
```sql
SELECT 
  e.engagement_id,
  e.booking_type,
  e.service_type,
  e.provider_gender_preference,
  e.serviceproviderid,
  sp.gender as assigned_provider_gender,
  e.created_at
FROM engagements e
LEFT JOIN serviceprovider sp ON sp.serviceproviderid = e.serviceproviderid
WHERE e.booking_type = 'ON_DEMAND'
  AND e.provider_gender_preference IS NOT NULL
ORDER BY e.created_at DESC
LIMIT 20;
```

### Check Gender Preference Match Success
```sql
-- For ON_DEMAND bookings, check if assigned provider matches preference
SELECT 
  e.provider_gender_preference,
  sp.gender as actual_provider_gender,
  CASE 
    WHEN e.provider_gender_preference = 'No Preference' THEN 'N/A'
    WHEN UPPER(e.provider_gender_preference) = UPPER(sp.gender) THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as match_status,
  COUNT(*) as count
FROM engagements e
INNER JOIN serviceprovider sp ON sp.serviceproviderid = e.serviceproviderid
WHERE e.booking_type = 'ON_DEMAND'
  AND e.serviceproviderid IS NOT NULL
  AND e.created_at >= NOW() - INTERVAL '30 days'
GROUP BY e.provider_gender_preference, sp.gender
ORDER BY e.provider_gender_preference, count DESC;
```

---

## Performance

### Index Created
```sql
CREATE INDEX idx_engagements_gender_preference 
  ON public.engagements(provider_gender_preference)
  WHERE provider_gender_preference IS NOT NULL 
    AND provider_gender_preference != 'No Preference';
```

**Why partial index?**
- Most bookings will use "No Preference" (default)
- Only index bookings that actually need gender filtering
- Reduces index size and improves write performance

### ServiceProvider Table
The `gender` column already exists and is indexed as part of other composite indexes used for provider search.

---

## Edge Cases Handled

1. **NULL gender values:** Provider not included in filtered results
2. **Empty string gender:** Provider not included in filtered results
3. **Case variations:** 'male', 'Male', 'MALE' all match "Male" preference
4. **Whitespace:** ' Male ', ' male' all match "Male" preference
5. **No providers match:** System widens radius to fallback distance (30km)
6. **Legacy bookings:** Existing engagements without preference are treated as "No Preference"

---

## Monitoring Queries

### Gender Preference Usage Statistics
```sql
SELECT 
  provider_gender_preference,
  booking_type,
  COUNT(*) as booking_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM engagements
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY provider_gender_preference, booking_type
ORDER BY booking_count DESC;
```

### Provider Assignment Success Rate by Gender
```sql
SELECT 
  e.provider_gender_preference,
  COUNT(*) as total_bookings,
  COUNT(e.serviceproviderid) as assigned_bookings,
  COUNT(e.serviceproviderid) * 100.0 / COUNT(*) as assignment_rate_percent
FROM engagements e
WHERE e.booking_type = 'ON_DEMAND'
  AND e.created_at >= NOW() - INTERVAL '7 days'
GROUP BY e.provider_gender_preference
ORDER BY total_bookings DESC;
```

---

**Note:** Replace latitude/longitude values (12.9716, 77.5946) in test queries with actual booking locations.
