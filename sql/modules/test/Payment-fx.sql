BEGIN;
\i Base.sql

--- COMMON SETUP
insert into users (entity_id, username, id)
values (-200, '_test1', -200);
INSERT INTO session (users_id, last_used, token)
values (currval('users_id_seq'),  now(), md5('test2'));
insert into session (session_id, users_id, token, last_used)
values (-200, -200, md5(random()::text), now());


INSERT INTO chart (accno, description, charttype, category, link)
VALUES ('00001', 'testing AP', 'A', 'L', 'AP'),
       ('00002', 'testing AP cost', 'A', 'E', 'AP_amount'),
       ('00003', 'testing cash', 'A', 'A', 'AP_paid');


-- TEST 1: payment_post() with fx rate 1.1

INSERT INTO company (id, legal_name, entity_id) VALUES (-101, 'TEST', -101);
INSERT INTO business (id, description) values (-101, 'test');
INSERT INTO entity_credit_account (id, meta_number, threshold, entity_id, entity_class, business_id, ar_ap_account_id)
     VALUES (-101, 'TEST1', 100000, -101, 1, -101, -1000);


INSERT INTO ap (id, transdate, amount_bc, amount_tc, invnumber, curr, entity_credit_account)
     VALUES (-11, '1901-01-01', 100, 110, 'inv_test1', 'XTS', -101);
INSERT INTO acc_trans (trans_id, transdate, amount_bc, curr, amount_tc, approved, chart_id)
     VALUES (-11, '1901-01-01', 100, 'XTS', 110, 't', (select id from account where accno = '00001'));

-- Pay the invoice in full
SELECT * FROM
  payment_post('1901-01-01', 1, -101, 'XTS', 1.10, NULL,
     'This gl movement is a consequence of a payment transaction',
     ARRAY[(SELECT id FROM account WHERE accno = '00003')],
     ARRAY[110], NULL, ARRAY['cash '], ARRAY[NULL],
     ARRAY[-11], NULL, NULL, NULL, NULL, NULL, NULL, 't');
--     ARRAY[-11], ARRAY[], ARRAY[], ARRAY[], ARRAY[], ARRAY[], NULL, 't');


select sum(amount_bc)
        from acc_trans
       where trans_id = -11
         and chart_id = (select id from account where accno = '00001');

select sum(amount_tc)
        from acc_trans
       where trans_id = -11
         and chart_id = (select id from account where accno = '00001');

INSERT INTO test_result (test_name, success)
VALUES
    ('Local currency marks fully paid',
     (select abs(sum(amount_bc))
        from acc_trans
       where trans_id = -11
         and chart_id = (select id from account where accno = '00001'))
     < 0.01),
    ('Foreign currency marks fully paid',
     (select abs(sum(amount_tc))
        from acc_trans
       where trans_id = -11
         and chart_id = (select id from account where accno = '00001'))
     < 0.01);


SELECT * FROM TEST_RESULT;

SELECT (select count(*) from test_result where success is true)
|| ' tests passed and '
|| (select count(*) from test_result where success is not true)
|| ' failed' as message;

 ROLLBACK;
