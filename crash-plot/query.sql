    select
        2014_incident.IncidentID as IncidentID,
        num.num as num_vehicles_involved,
        eCollisionManner, Longitude, Latitude, InjurySeverity,
        eIntersectionType,
        eCollisionManner,
        LOVCity.name as city_name,
        IncidentDateTime,
        (   
            select group_concat(person1.eViolation1 separator '+')
            from 2014_unit as unit1
            join 2014_person as person1 on unit1.UnitID = person1.UnitID and unit1.IncidentID = person1.IncidentID
            where unit1.IncidentID = 2014_incident.IncidentID
            and unit1.eUnitType = 'PEDALCYCLIST'
        ) as cyclist_citations,
        (   
            select group_concat(person2.eViolation1 separator '+')
            from 2014_unit as unit2
            join 2014_person as person2 on unit2.UnitID = person2.UnitID and unit2.IncidentID = person2.IncidentID
            where unit2.IncidentID = 2014_incident.IncidentID
            and unit2.eUnitType = 'DRIVER'
        ) as driver_citations
    from 2014_incident
    left join LOVCity on 2014_incident.CityId = LOVCity.id
    join (
        select count(*) as num, IncidentID from 2014_unit
        group by IncidentID
    ) as num on num.IncidentID = 2014_incident.IncidentID
    where 2014_incident.IncidentID in (
        select IncidentID from 2014_unit where 2014_unit.eUnitType = 'PEDALCYCLIST'
    )
    and 2014_incident.IncidentID in (
        select IncidentID from 2014_unit where 2014_unit.eUnitType = 'DRIVER'
    )
    group by 2014_incident.IncidentID

