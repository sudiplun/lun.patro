// Regression tests for lun.patro Model.js.
// Run with: node tests/model-test.js

"use strict"

const path = require("path")
const Model = require(path.join(__dirname, "..", "Model.js"))

let failures = 0

function assert(condition, message) {
  if (!condition) {
    failures++
    console.error("FAIL: " + message)
  } else {
    console.log("ok: " + message)
  }
}

function assertEqual(actual, expected, message) {
  const ok = actual === expected
  if (!ok) {
    failures++
    console.error(
      "FAIL: " + message + " (expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual) + ")"
    )
  } else {
    console.log("ok: " + message)
  }
}

// ---- BS date conversion ----
// 14 April 2022 = 1 Baishakh 2079
const base = new Date(Date.UTC(2022, 3, 14))
const bs = Model.bsDateFor(base)
assertEqual(bs.year, 2079, "bsDateFor: 2022-04-14 -> BS year 2079")
assertEqual(bs.month, 0, "bsDateFor: 2022-04-14 -> BS month Baishakh (0)")
assertEqual(bs.day, 1, "bsDateFor: 2022-04-14 -> BS day 1")

// Round trip: BS -> AD -> BS
const back = Model.bsToAd(2079, 0, 1)
assertEqual(back.getUTCFullYear(), 2022, "bsToAd round trip: year")
assertEqual(back.getUTCMonth(), 3, "bsToAd round trip: month (April)")
assertEqual(back.getUTCDate(), 14, "bsToAd round trip: day")

// Invalid BS date returns null
assertEqual(Model.bsToAd(2079, 0, 32), null, "bsToAd: invalid day returns null")

// ---- Week start ----
assertEqual(Model.normalizedWeekStart(1, 1), 1, "normalizedWeekStart: 1 -> 1")
assertEqual(Model.normalizedWeekStart(0, 1), 0, "normalizedWeekStart: 0 -> 0")
assertEqual(Model.normalizedWeekStart(null, 1), 1, "normalizedWeekStart: null -> fallback 1")
assertEqual(Model.normalizedWeekStart("sunday", 1), 0, "normalizedWeekStart: 'sunday' -> 0")
assertEqual(Model.normalizedWeekStart("mon", 1), 1, "normalizedWeekStart: 'mon' -> 1")
assertEqual(Model.normalizedWeekStart("garbage", 3), 3, "normalizedWeekStart: garbage -> fallback")

// ---- Weekday order ----
const orderMon = Model.weekdayOrder(1)
assertEqual(orderMon[0], 1, "weekdayOrder: Monday start -> first is Monday")
assertEqual(orderMon[6], 0, "weekdayOrder: Monday start -> last is Sunday")

const orderSun = Model.weekdayOrder(0)
assertEqual(orderSun[0], 0, "weekdayOrder: Sunday start -> first is Sunday")

// ---- Toggled week start ----
assertEqual(Model.toggledWeekStart(1, 1), 0, "toggledWeekStart: Monday -> Sunday")
assertEqual(Model.toggledWeekStart(0, 1), 1, "toggledWeekStart: Sunday -> Monday")

// ---- ISO week ----
// 2026-01-01 is a Thursday, ISO week 1
assertEqual(Model.isoWeek(2026, 0, 1), 1, "isoWeek: 2026-01-01 -> week 1")

// ---- Year progress ----
assertEqual(Model.yearProgress(2026, 0, 1), 0, "yearProgress: Jan 1 -> 0")
assertEqual(Model.yearProgressPercent(2026, 11, 31), 100, "yearProgressPercent: Dec 31 -> 100")

// ---- parseAge / parseBirthYear ----
assertEqual(Model.parseAge("47"), 47, "parseAge: '47' -> 47")
assertEqual(Model.parseAge("abc"), 0, "parseAge: 'abc' -> 0")
assertEqual(Model.parseAge("-5"), 0, "parseAge: '-5' -> 0")
assertEqual(Model.parseAge(""), 0, "parseAge: '' -> 0")

assertEqual(Model.parseBirthYear("1979", 2026), 1979, "parseBirthYear: '1979' -> 1979")
assertEqual(Model.parseBirthYear("9999", 2026), 0, "parseBirthYear: future year -> 0")
assertEqual(Model.parseBirthYear("", 2026), 0, "parseBirthYear: '' -> 0")

// ---- ageFromBirthYear ----
assertEqual(Model.ageFromBirthYear(1979, 2026), 47, "ageFromBirthYear: 1979 -> 47 in 2026")

// ---- clock format ring ----
const ring = Model.clockFormatRing("HH:mm", "d MMMM", ["HH:mm", "HH:mm:ss"])
assertEqual(ring[0], "HH:mm", "clockFormatRing: first preset")
assertEqual(ring.indexOf("d MMMM") !== -1, true, "clockFormatRing: includes configuredAlt")
assertEqual(ring.indexOf("HH:mm") !== -1, true, "clockFormatRing: includes configured")

// ---- nextClockFormat ----
assertEqual(Model.nextClockFormat(["HH:mm", "HH:mm:ss"], "HH:mm"), "HH:mm:ss", "nextClockFormat: walks to next")
assertEqual(Model.nextClockFormat(["HH:mm", "HH:mm:ss"], "HH:mm:ss"), "HH:mm", "nextClockFormat: wraps around")

// ---- monthGrid: always 6 rows ----
const grid = Model.monthGrid(2026, 0, 1, "2026-01-01")
assertEqual(grid.length, 6, "monthGrid: always 6 weeks")
grid.forEach(function (week, i) {
  assertEqual(week.days.length, 7, "monthGrid week " + i + ": 7 days")
})

// ---- today key matches ----
const todayKey = Model.dateKey(2026, 0, 15)
const todayCell = grid.some(function (week) {
  return week.days.some(function (day) { return day.today })
})
assert(todayCell, "monthGrid: marks today")

console.log("\n" + (failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED"))
process.exit(failures === 0 ? 0 : 1)
