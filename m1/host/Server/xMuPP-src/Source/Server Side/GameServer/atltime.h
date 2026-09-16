#pragma once
// Minimal ATL-compatible CTime/CTimeSpan for building GameServer without ATL/MFC installed.
#include <ctime>
#include <cstdint>

class CTimeSpan
{
public:
	CTimeSpan() : m_span(0) {}
	CTimeSpan(__time64_t span) : m_span(span) {}
	CTimeSpan(int days, int hours, int minutes, int seconds)
		: m_span(((__time64_t)days) * 86400 + ((__time64_t)hours) * 3600 + ((__time64_t)minutes) * 60 + seconds) {}

	__time64_t GetTimeSpan() const { return m_span; }

	friend class CTime;
private:
	__time64_t m_span;
};

class CTime
{
public:
	CTime() : m_time(0) {}
	explicit CTime(__time64_t t) : m_time(t) {}

	CTime(int year, int month, int day, int hour, int minute, int second, int /*dst*/)
	{
		if (day < 1) day = 1;
		if (month < 1) month = 1;
		if (month > 12) month = 12;
		tm t = {};
		t.tm_year = year - 1900;
		t.tm_mon = month - 1;
		t.tm_mday = day;
		t.tm_hour = hour;
		t.tm_min = minute;
		t.tm_sec = second;
		t.tm_isdst = -1;
		m_time = _mktime64(&t);
		if (m_time == -1) m_time = 0;
	}

	static CTime GetTickCount()
	{
		return CTime(_time64(nullptr));
	}

	__time64_t GetTime() const { return m_time; }

	int GetYear() const { return Local().tm_year + 1900; }
	int GetMonth() const { return Local().tm_mon + 1; }
	int GetDay() const { return Local().tm_mday; }
	int GetHour() const { return Local().tm_hour; }
	int GetMinute() const { return Local().tm_min; }
	int GetSecond() const { return Local().tm_sec; }
	// ATL: 1 = Sunday .. 7 = Saturday
	int GetDayOfWeek() const { return Local().tm_wday + 1; }

	CTime operator+(const CTimeSpan& span) const { return CTime(m_time + span.GetTimeSpan()); }
	CTime& operator+=(const CTimeSpan& span) { m_time += span.GetTimeSpan(); return *this; }
	CTimeSpan operator-(const CTime& other) const { return CTimeSpan(m_time - other.m_time); }

	bool operator<(const CTime& other) const { return m_time < other.m_time; }
	bool operator>(const CTime& other) const { return m_time > other.m_time; }
	bool operator<=(const CTime& other) const { return m_time <= other.m_time; }
	bool operator>=(const CTime& other) const { return m_time >= other.m_time; }
	bool operator==(const CTime& other) const { return m_time == other.m_time; }
	bool operator!=(const CTime& other) const { return m_time != other.m_time; }

private:
	tm Local() const
	{
		tm t = {};
		_localtime64_s(&t, &m_time);
		return t;
	}

	__time64_t m_time;
};
