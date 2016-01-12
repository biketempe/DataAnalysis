copy (
    select location_id, count_tmp.bikes, count(collisions.nearest_count_site) as collisions, count(*) / bikes as collisions_by_bikes
    from (
        select location_id, avg(bikes_tmp) as bikes
        from (
            select location_id, sum(count) as bikes_tmp, year
            from count
            group by location_id, year
            order by location_id
        ) as count_tmp_tmp
        group by location_id
    ) as count_tmp
    left join collisions on count_tmp.location_id = collisions.nearest_count_site
    group by count_tmp.location_id, count_tmp.bikes
    order by location_id
) to '/tmp/accident_rate.csv' delimiter ',' csv;

