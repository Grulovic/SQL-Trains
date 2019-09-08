--------------------------------------------------------
--Stefan Grulovic (20150280) -> Final Project
--------------------------------------------------------
--EMPLOYEE DETAILS NEW TABLE 
--------------------------------------------------------
DROP TABLE EMP_DETAILS CASCADE CONSTRAINTS;

CREATE TABLE EMP_DETAILS(
EMP_DETAIL_ID    VARCHAR(5),
EMP_ID VARCHAR(5),
EMP_ON_TIME		NUMBER,
EMP_NUM_OF_OP	NUMBER,
EMP_TOTAL_OP_DUR	NUMBER,
CONSTRAINT EMP_DETAILS_PK PRIMARY KEY (EMP_DETAIL_ID)
);


--Insert into for emp details
insert into emp_details
select rownum, sub2.emp_id, ot.on_time_amount, sub2.NUM_OF_OPERATIONS, sub2.TOTAL_OPERATION_TIME
from
(SELECT sub.emp_id, COUNT(operation_id) NUM_OF_OPERATIONS,
	to_char(NUMTODSINTERVAL( SUM(extract (day FROM (sub.op_duration)) * 86400
                    + extract (hour FROM (sub.op_duration)) * 3600
                    + extract (minute FROM (sub.op_duration)) * 600
                    + extract (second FROM (sub.op_duration))
              		), 'SECOND'), 'HH:MI:SS') TOTAL_OPERATION_TIME
	FROM
	(SELECT max.operation_id, o1.emp_id, (max.end_time - min.start_time) op_duration
	FROM operations o1,
		(SELECT od.operation_id, od.actual_time end_time, od.stop_order
		FROM  op_details od,
			(SELECT s1.operation_id, max(s1.stop_order) stop_order
			FROM op_details s1
			GROUP BY s1.operation_id) sub
		WHERE sub.operation_id = od.operation_id
			AND sub.stop_order = od.stop_order) max,

				(SELECT od1.operation_id, od1.actual_time start_time, od1.stop_order
				FROM  op_details od1,
					(SELECT s2.operation_id, min(s2.stop_order) stop_order
					FROM op_details s2
					GROUP BY s2.operation_id) sub2
				WHERE sub2.operation_id = od1.operation_id
					AND sub2.stop_order = od1.stop_order) min
	WHERE max.operation_id=min.operation_id
		AND o1.operation_id = max.operation_id
		AND o1.operation_id = min.operation_id
	ORDER BY max.operation_id) sub
	GROUP BY sub.emp_id
	ORDER BY sub.emp_id) sub2

	,(SELECT o.emp_id, COUNT(o.emp_id) ON_TIME_AMOUNT
		FROM op_details od, operations o
		WHERE to_char(od.expected_time, 'DD-MM-YYYY HH24:MI:SS') = to_char(od.actual_time, 'DD-MM-YYYY HH24:MI:SS')
			AND o.operation_id = od.operation_id
		GROUP BY emp_id
		ORDER BY COUNT(o.emp_id) desc) ot
WHERE ot.emp_id = sub2.emp_id

--Trigger that check the operation table and if the employee has changed the changes reflect to the employee details table aswell
--also if a new operation has been added the data of number of operations in employee details also changes
CREATE OR REPLACE TRIGGER emp_detail_change
AFTER INSERT OR DELETE OR UPDATE ON operations
FOR EACH ROW
DECLARE
	
BEGIN
	IF UPDATING and :old.EMP_ID != :new.EMP_ID THEN
		UPDATE emp_details
		SET EMP_NUM_OF_OP = EMP_NUM_OF_OP - 1
		WHERE emp_id = :old.emp_id;

		UPDATE emp_details
		SET EMP_NUM_OF_OP = EMP_NUM_OF_OP + 1
		WHERE emp_id = :new.emp_id;
	END IF;

	IF DELETING THEN
		UPDATE emp_details
		SET EMP_NUM_OF_OP = EMP_NUM_OF_OP - 1
		WHERE emp_id = :old.emp_id;
	END IF;

	IF INSERTING THEN
		UPDATE emp_details
		SET EMP_NUM_OF_OP = EMP_NUM_OF_OP + 1
		WHERE emp_id = :new.emp_id;
	END IF;
END;
--------------------------------------------------------
--LINES ADDITIONAL DETAILS
--------------------------------------------------------

ALTER TABLE LINES
ADD LINE_NUM_OF_OP NUMBER;
ALTER TABLE LINES
ADD LINE_AVG_PASSG_PER_OP NUMBER;

--Trigger that takes care of the number of operation the line has had and if changes happen to operations, line number of operation also change
CREATE OR REPLACE TRIGGER lines_op_num
AFTER INSERT OR DELETE OR UPDATE ON operations
FOR EACH ROW
DECLARE
BEGIN
	IF DELETING OR UPDATING THEN
		UPDATE lines
		SET LINE_NUM_OF_OP = LINE_NUM_OF_OP - 1
		WHERE line_id = :old.line_id;
	END IF;
	IF INSERTING OR UPDATING THEN
		UPDATE lines
		SET LINE_NUM_OF_OP = LINE_NUM_OF_OP + 1
		WHERE line_id = :new.line_id;
	END IF;
END;
--Procedure that calculates the lines average number of passengers per operation
CREATE OR REPLACE PROCEDURE line_avg_passangers_per_op
IS
	CURSOR lines_cur IS
	SELECT *
	FROM lines;
	
	lines_rec lines_cur%ROWTYPE;
BEGIN
	OPEN lines_cur;
		LOOP
			FETCH lines_cur INTO lines_rec;
			EXIT WHEN lines_cur%NOTFOUND;
    UPDATE lines
    SET LINE_AVG_PASSG_PER_OP = (select avg from 
									(select o.line_id, ROUND(AVG(od.num_of_passangers),1) as "AVG"
										from op_details od, operations o
										where od.operation_id = o.operation_id
										group by o.line_id)
									where line_id =lines_rec.line_id)
	where line_id =lines_rec.line_id;
		END LOOP;
END;

--------------------------------------------------------
--OPERATIONS ADDITIONAL DETAILS
--------------------------------------------------------

ALTER TABLE OPERATIONS
ADD OP_DURATION NUMBER;
ALTER TABLE OPERATIONS
ADD OP_NUM_OF_DELAYS NUMBER;

--Procedure that updates the operation duration in the operation table that has been extended 
CREATE OR REPLACE PROCEDURE operation_duration_time
IS
	CURSOR operation_cur IS
	SELECT *
	FROM operations;
	
	operation_rec operation_cur%ROWTYPE;
BEGIN
	OPEN operation_cur;
		LOOP
			FETCH operation_cur INTO operation_rec;
			EXIT WHEN operation_cur%NOTFOUND;
    UPDATE operations
    SET OP_DURATION  = (select op_duration from (SELECT max.operation_id, (max.end_time - min.start_time) op_duration
						FROM
							(SELECT od.operation_id, od.actual_time end_time, od.stop_order
							FROM  op_details od,
								(SELECT s1.operation_id, MAX(s1.stop_order) stop_order
									FROM op_details s1
									GROUP BY s1.operation_id) sub
								WHERE sub.operation_id = od.operation_id
									AND sub.stop_order = od.stop_order) max,

									(SELECT od1.operation_id, od1.actual_time start_time, od1.stop_order
									FROM  op_details od1,
										(SELECT s2.operation_id, MIN(s2.stop_order) stop_order
										FROM op_details s2
										GROUP BY s2.operation_id) sub2
									WHERE sub2.operation_id = od1.operation_id
										AND sub2.stop_order = od1.stop_order) min
						WHERE max.operation_id=min.operation_id
						ORDER BY max.operation_id)
    				WHERE operation_id =operation_rec.operation_id)
	where operation_id = operation_rec.operation_id;
	END LOOP;
END;

--Procedure that calculates the number of delays per operation and updates the operations table
CREATE OR REPLACE PROCEDURE operation_num_of_delays
IS
	CURSOR operation_cur IS
	SELECT *
	FROM operations;
	
	operation_rec operation_cur%ROWTYPE;
BEGIN
	OPEN operation_cur;
		LOOP
			FETCH operation_cur INTO operation_rec;
			EXIT WHEN operation_cur%NOTFOUND;
    UPDATE operations
    SET OP_NUM_OF_DELAYS  = (select NUM_OF_DELAYS from 
									(SELECT operation_id, COUNT(operation_id) NUM_OF_DELAYS
									FROM op_details
									WHERE (expected_time - actual_time) < '000000000 00:00:00.000000'
									GROUP BY operation_id
									ORDER BY operation_id)
							where operation_id =operation_rec.operation_id)
	where operation_id =operation_rec.operation_id;
	END LOOP;
END;

--------------------------------------------------------
--FUNCTIONS
--------------------------------------------------------

--Function that shows for specific driver id his total operations
CREATE OR REPLACE FUNCTION count_emp_operations 
(id EMP.EMP_ID%TYPE)
	RETURN NUMBER
IS
	temp NUMBER;
BEGIN
	select count(*)
	into temp
	from operations
	where emp_id = id
	;
	
	RETURN temp;
END; 

--------------------------------------------------------
--PROCEDURES WITH SENTANCE
--------------------------------------------------------

--Procedures that shows the employee who is getting on expected time the most and it presents the answer in sentance form
CREATE OR REPLACE PROCEDURE emp_most_on_time
IS 
	temp_id EMP.EMP_ID%TYPE;
	temp_name emp.emp_name%type;
	temp_lname	emp.emp_lname%type;
	temp_on_time number;
BEGIN
	SELECT e.emp_name, e.emp_lname, max.*
	into temp_name, temp_lname, temp_id, temp_on_time
	FROM (SELECT o.emp_id, COUNT(o.emp_id) ON_TIME_AMOUNT
			FROM op_details od, operations o
			WHERE to_char(od.expected_time, 'DD-MM-YYYY HH24:MI:SS') = to_char(od.actual_time, 'DD-MM-YYYY HH24:MI:SS')
				AND o.operation_id = od.operation_id
			GROUP BY emp_id
			ORDER BY COUNT(o.emp_id) desc) max, emp e 
	WHERE rownum = 1
		AND e.emp_id = max.emp_id;


	DBMS_OUTPUT.PUT_LINE (temp_lname||' '||temp_name||'('||temp_id||')'||'is the employee who got his train on expected time the most, in total of '
							||temp_on_time||' times. ');
END;

--Procedure that shows the schedule which has the longest average operation time
CREATE OR REPLACE PROCEDURE longest_avg_schedule
IS 
	temp_sched SCHEDULES.SCHEDULE_ID%TYPE;
	temp_avg_time VARCHAR2(100);
BEGIN
	SELECT * 
	INTO temp_sched, temp_avg_time
	FROM (SELECT sub.schedule_id, to_char(NUMTODSINTERVAL( AVG(extract (day FROM (sub.op_duration)) * 86400
	                    + extract (hour FROM (sub.op_duration)) * 3600
	                    + extract (minute FROM (sub.op_duration)) * 600
	                    + extract (second FROM (sub.op_duration))
	              		), 'SECOND'), 'HH:MI:SS') AVERAGE_OPERATION_TIME
	FROM
	(SELECT max.operation_id, o.schedule_id, (max.end_time - min.start_time) op_duration
		FROM
		operations o,
			(SELECT od.operation_id, od.actual_time end_time, od.stop_order
			FROM  op_details od,
				(SELECT s1.operation_id, MAX(s1.stop_order) stop_order
				FROM op_details s1
				GROUP BY s1.operation_id) sub
				WHERE sub.operation_id = od.operation_id
				AND sub.stop_order = od.stop_order) max,

					(SELECT od1.operation_id, od1.actual_time start_time, od1.stop_order
					FROM  op_details od1,
						(SELECT s2.operation_id, MIN(s2.stop_order) stop_order
						FROM op_details s2
						GROUP BY s2.operation_id) sub2
					WHERE sub2.operation_id = od1.operation_id
						AND sub2.stop_order = od1.stop_order) min
		WHERE max.operation_id=min.operation_id
		AND o.operation_id = max.operation_id
		ORDER BY op_duration DESC) sub
	GROUP BY sub.schedule_id
	ORDER BY AVERAGE_OPERATION_TIME  DESC)
	WHERE rownum = 1;


	DBMS_OUTPUT.PUT_LINE ('Schedule with the longest average time of duration is '||temp_sched||', and it usually lasts '||temp_avg_time||'. ');
END;
--------------------------------------------------------