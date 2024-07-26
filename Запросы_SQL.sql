--========  ИТОГОВАЯ РАБОТА  ==============

--ЗАДАНИЕ №1
--Выведите названия самолётов, которые имеют менее 50 посадочных мест.
select a.model as "название самолёта", count (s.seat_no) as "количество посадочных мест"
from seats s
join aircrafts a on a.aircraft_code = s.aircraft_code 
group by s.aircraft_code, a.model  
having count(seat_no) < 50



--ЗАДАНИЕ №2
--Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
select date_trunc('month', book_date)::date as "месяц", sum (total_amount) as "сумма бронирования билетов",
coalesce (round ((sum (total_amount) - lag(sum(total_amount)) over(order by date_trunc('month', book_date))) / lag (sum(total_amount)) over (order by date_trunc('month', book_date)) *100, 2), 0) as "изменение в %"
from bookings
group by date_trunc('month', book_date)
order by date_trunc('month', book_date) 



--ЗАДАНИЕ №3
--Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.
select a.model as "названия самолётов" 
from (
     select aircraft_code, array_agg(fare_conditions)  
     from seats
     group by aircraft_code) as s
join aircrafts a on s.aircraft_code = a.aircraft_code
where array_position(s.array_agg, 'Business') is null



--ЗАДАНИЕ №4
--Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день. 
--Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
--Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.
with cte as (
        select aircraft_code, count (seat_no)
        from seats
        group by aircraft_code)
select  p.departure_airport as "код аэропорта", p.actual_departure::date as "дата вылета", cte."count" as "количество пустых мест", 
        sum (cte."count") over (partition by p.departure_airport, p.actual_departure::date order by p.actual_departure) as "накопительный итог"
from (
     select f.departure_airport, f.aircraft_code, f.actual_departure,
            count (f.flight_id) over (partition by f.departure_airport, f.actual_departure::date)
     from flights f   
     left join boarding_passes bp on f.flight_id = bp.flight_id
     where bp.boarding_no is null and f.status in ('Arrived', 'Departed')) as p
join cte on cte.aircraft_code = p.aircraft_code
where p."count" > 1  



--ЗАДАНИЕ №5
--Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. 
--Выведите в результат названия аэропортов и процентное отношение.
--Используйте в решении оконную функцию.
select distinct departure_airport_name as "аэропорт вылета", arrival_airport_name as "аэропорт прилёта",
round (count (flight_id) over (partition by flight_no)*100./count (flight_id) over (), 2) as "процентное соотношение"
from flights_v



--ЗАДАНИЕ №6
--Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7
select substring(contact_data ->>'phone' from 3 for 3) as "коды сотового оператора", count (*) as "количество пассажиров"
from tickets
group by 1
order by 1



--ЗАДАНИЕ №7
--Классифицируйте финансовые обороты (сумму стоимости перелетов) по маршрутам:
--до 50 млн – low
--от 50 млн включительно до 150 млн – middle
--от 150 млн включительно – high
--Выведите в результат количество маршрутов в каждом полученном классе.
select count (case when p.sum < 50000000 then p.sum end) as "low",
       count (case when p.sum >= 50000000 and p.sum < 150000000 then p.sum end) as "middle",
       count (case when p.sum >= 150000000 then p.sum end) as "high"
from (
      select f.flight_no, sum (tf.amount) 
      from flights f 
      join ticket_flights tf on tf.flight_id = f.flight_id
      group by f.flight_no) as p



--ЗАДАНИЕ №8
--Вычислите медиану стоимости перелетов (amount), медиану стоимости бронирования и отношение медианы бронирования к медиане стоимости перелетов, результат округлите до сотых.
with cte1 as (
             select percentile_cont(0.5) within group (order by amount)
             from ticket_flights),
cte2 as (
         select percentile_cont(0.5) within group (order by total_amount)
         from bookings)
select  cte1.percentile_cont as  "медиана стоимости перелётов", cte2.percentile_cont as "медиана стоимости бронирования", round((cte2.percentile_cont/cte1.percentile_cont)::numeric,2) as "отношение медиан"
from cte1, cte2



--ЗАДАНИЕ №9
--Найдите значение минимальной стоимости одного километра полёта для пассажира. Для этого определите расстояние между аэропортами и учтите стоимость перелета.
--Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. Для работы данного модуля нужно установить ещё один модуль – cube.
--Важно: Установка дополнительных модулей происходит через оператор CREATE EXTENSION название_модуля.
--Функция earth_distance возвращает результат в метрах.
create extension if not exists cube
with schema bookings 

create extension if not exists earthdistance
with schema bookings 


select round (p.amount / p."расстояние между аэропортами"::numeric, 2) as "минимальная стоимость 1 км полёта"
from (
     select a1.airport_code, a1.longitude, a1.latitude, a2.airport_code, a2.longitude, a2.latitude, tf.amount,  
       earth_distance (ll_to_earth (a1.latitude, a1.longitude), ll_to_earth (a2.latitude, a2.longitude)) / 1000 as "расстояние между аэропортами"
     from flights f
     join airports a1 on a1.airport_code = f.departure_airport 
     join airports a2 on a2.airport_code = f.arrival_airport
     join ticket_flights tf on tf.flight_id = f.flight_id
     group by a1.airport_code, a2.airport_code, tf.amount) as p 
order by p.amount / p."расстояние между аэропортами"
limit 1
