#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logFile> <title> [-k]"
  echo "<logfile> the name to assign to the local copy of the log file"
  echo "-k: do not delete temp files after parsing log file"
  exit 1
fi
logFile=$1
label=$2
keepTemp=$3
db=$label.db
tfDir=tmp
mkdir -p $tfDir
mkdir -p $(dirname $db)

tfb=$(tempfile -d $tfDir)
logTf=$tfb.log
schedTf=$tfb.sched
rxlTf=$tfb.rxl
txlTf=$tfb.txl
cflTf=$tfb.cf
fwlTf=$tfb.fwl

if [ $(file $logFile | grep -c 'CRLF') -eq 1 ]
then
  echo "strip non-ascii characters"
  pv $logFile | tr -cd '\11\12\15\40-\176' > $logTf

  echo "convert line endings"
  dos2unix $logTf
else 
  echo "skip convert line endings"
  cp $logFile $logTf
fi

echo "extracting SCHED events"
# 1368558936.2  25   SCHED RX 241    1  802      11
# 1368558936.21 0    SCHED TX 241    1  802      802
# ts            node          sched# sn csRemote csLocal
# 1             2             3      4  5        6
pv $logTf | grep 'SCHED' | cut -d ' ' -f 3,4 --complement > $schedTf

echo "extracting RX_LOCAL events"
# 1368558911.19 43   NRX 0   0  894      2  916881 923320    65535 -79  1
# tsReport      node     src sn ofnLocal hc rx32k  report32k dest  rssi lqi
# 1             2        3   4  5        6  7      8         9     10   11
pv $logTf | grep 'NRX' | cut -d ' ' -f 3 --complement > $rxlTf

echo "extracting TX_LOCAL events"
# 1368558936.21 0   NTX 1  803      822299 829762    65535 2  0   196
# tsReport      src     sn ofnLocal tx32k  report32k dest  tp stp AMID
# 1             2       3  4        5      6         7     8  9   10
pv $logTf | grep 'NTX' | cut -d ' ' -f 3 --complement > $txlTf

echo "extracting CRCF_LOCAL events"
# 1368558910.98 4    CRCF 981
# ts            node      fnLocal
pv $logTf | grep 'CRCF' | cut -d ' ' -f 3 --complement > $cflTf

echo "extracting FW_LOCAL events"
# 1368558936.01 25   NFW 12       2
# ts            node     ofnLocal hc
pv $logTf | grep 'NFW' | cut -d ' ' -f 3 --complement > $fwlTf


sqlite3 $db << EOF
.headers OFF
.separator ' '

--for stdev computation
SELECT load_extension('/home/carlson/local/bin/libsqlitefunctions.so');

DROP TABLE IF EXISTS SCHED_TMP;
CREATE TEMPORARY TABLE SCHED_TMP (
  ts REAL,
  node INTEGER,
  schedNum INTEGER,
  sn INTEGER,
  csRemote INTEGER,
  csLocal INTEGER);

SELECT "Importing SCHED";
.import $schedTf SCHED_TMP

SELECT "Ordering SCHED";
DROP TABLE IF EXISTS SCHED;
CREATE TABLE SCHED AS 
  SELECT * FROM SCHED_TMP ORDER BY node, ts;

DROP TABLE IF EXISTS RX_LOCAL;
CREATE TABLE RX_LOCAL (
  reportTs REAL,
  dest INTEGER,
  src INTEGER,
  sn INTEGER,
  ofnLocal INTEGER,
  depth INTEGER,
  rx32k INTEGER,
  report32k INTEGER,
  pdest INTEGER,
  rssi INTEGER,
  lqi INTEGER);

SELECT "Importing RX_LOCAL";
.import $rxlTf RX_LOCAL

SELECT "Mapping RX_LOCAL to RX_ALL";
DROP TABLE IF EXISTS RX_ALL;
CREATE TABLE RX_ALL AS
SELECT RX_LOCAL.*, 
  ofnLocal-csLocal + depth-1 as fnCycle, 
  ofnLocal-csLocal + csRemote + depth-1 as fnGlobal,
  cycleNum,
  1 as received
FROM RX_LOCAL
JOIN (
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node) as s
ON RX_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext 
  AND RX_LOCAL.dest == s.node ;


DROP TABLE IF EXISTS TX_LOCAL;
CREATE TABLE TX_LOCAL (
  reportTs REAL,
  src INTEGER,
  sn INTEGER,
  ofnLocal INTEGER,
  tx32k INTEGER,
  report32k INTEGER,
  dest INTEGER,
  tp INTEGER,
  stp INTEGER,
  amId INTEGER);

SELECT "Importing TX_LOCAL";
.import $txlTf TX_LOCAL

SELECT "Mapping TX_LOCAL to TX_ALL";
DROP TABLE IF EXISTS TX_ALL;
-- Join each TX_LOCAL record with preceding SCHED and put in
-- standardized cycle-local and global frame numbers, as well as
-- cycle number.
CREATE TABLE TX_ALL AS
SELECT TX_LOCAL.*, 
  ofnLocal-csLocal as fnCycle, 
  ofnLocal-csLocal + csRemote as fnGlobal,
  cycleNum
FROM TX_LOCAL
JOIN (
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node) as s
ON TX_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext 
  AND TX_LOCAL.src == s.node;

DROP TABLE IF EXISTS FW_LOCAL;
CREATE TABLE FW_LOCAL (
  ts REAL,
  node INTEGER,
  ofnLocal INTEGER,
  depth INTEGER);

SELECT "Importing FW_LOCAL";
.import $fwlTf  FW_LOCAL

SELECT "Mapping FW_LOCAL to FW_ALL";
DROP TABLE IF EXISTS FW_ALL;
CREATE TABLE FW_ALL AS
SELECT FW_LOCAL.*, 
  orig.src as src, orig.sn as sn,
  fw_local.ofnLocal-csLocal + depth-1 as fnCycle, 
  fw_local.ofnLocal-csLocal + csRemote + depth-1 as fnGlobal,
  cycleNum
FROM FW_LOCAL
JOIN (
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node) as s
ON FW_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext 
  AND FW_LOCAL.node == s.node 
JOIN ( 
  SELECT RX_ALL.ofnLocal as ofnLocal, RX_ALL.src as src, RX_ALL.dest as node, RX_ALL.sn as sn FROM RX_ALL
  UNION SELECT TX_ALL.ofnLocal, TX_ALL.src, TX_ALL.src, TX_ALL.sn FROM TX_ALL) orig
ON orig.ofnLocal == fw_local.ofnLocal AND orig.node == fw_local.node
;


DROP TABLE IF EXISTS CRCF_LOCAL;
CREATE TABLE CRCF_LOCAL (
  ts REAL,
  node INTEGER,
  fnLocal INTEGER);

SELECT "Importing CRCF_LOCAL";
.import $cflTf CRCF_LOCAL

SELECT "Mapping CRCF_LOCAL to CRCF_ALL";
DROP TABLE IF EXISTS CRCF_ALL;
CREATE TABLE CRCF_ALL AS
SELECT CRCF_LOCAL.*, 
  CRCF_LOCAL.fnLocal-csLocal as fnCycle, 
  CRCF_LOCAL.fnLocal-csLocal + csRemote as fnGlobal,
  cycleNum
FROM CRCF_LOCAL
JOIN (
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node) as s
ON CRCF_LOCAL.fnLocal BETWEEN s.csLocal and s.csNext 
  AND CRCF_LOCAL.node == s.node 
;

SELECT "Aggregating depth info";
DROP TABLE IF EXISTS AGG_DEPTH;
CREATE TABLE AGG_DEPTH AS 
SELECT src,
  dest,
  min(depth) as minDepth,
  max(depth) as maxDepth,
  avg(depth) as avgDepth,
  stdev(depth) as sdDepth,
  count(*) as cnt
FROM RX_ALL
GROUP BY src, dest
ORDER BY avgDepth;

select "Finding missing receptions";
DROP TABLE IF EXISTS MISSING_RX;
CREATE TABLE MISSING_RX AS
SELECT TX_ALL.src, 
  nodes.dest, 
  TX_ALL.sn
FROM TX_ALL
  JOIN (SELECT DISTINCT RX_ALL.dest FROM RX_ALL) nodes 
  ON TX_ALL.dest == nodes.dest 
     OR (TX_ALL.dest == 65535 AND TX_ALL.src != nodes.dest)
EXCEPT SELECT RX_ALL.src, RX_ALL.dest, RX_ALL.sn FROM RX_ALL;

select "Computing Raw PRRs";
DROP TABLE IF EXISTS PRR;
CREATE TABLE PRR AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.stp as stp,
  avg(RX_AND_MISSING.received) as prr,
  count(RX_AND_MISSING.received) as cnt
FROM TX_ALL
LEFT JOIN (
  SELECT src, dest, sn, received FROM RX_ALL 
  UNION 
  SELECT src, dest, sn, 0 as received FROM MISSING_RX) RX_AND_MISSING ON
  TX_ALL.src == RX_AND_MISSING.src AND
  TX_ALL.sn == RX_AND_MISSING.sn 
GROUP BY TX_ALL.src,
  RX_AND_MISSING.dest,
  TX_ALL.tp,
  TX_ALL.stp
ORDER BY prr;

-- Placeholders
SELECT "PRR_CLEAN placeholder (copy PRR)";
DROP TABLE IF EXISTS PRR_CLEAN;
CREATE TABLE PRR_CLEAN AS 
SELECT * FROM PRR;

SELECT "ERROR_EVENTS placecholder (empty)";
DROP TABLE IF EXISTS ERROR_EVENTS;
CREATE TABLE ERROR_EVENTS (
  ts REAL,
  node INTEGER,
  fromState TEXT,
  toState TEXT
);
EOF


if [ "$keepTemp" != "-k" ]
then
  rm $tfb
  rm $logTf
  rm $schedTf
  rm $rxlTf
  rm $txlTf
  rm $cflTf
  rm $fwlTf
fi
