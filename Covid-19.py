#!/usr/bin/env python
# coding: utf-8

import pandas as pd 
import numpy as np
import matplotlib.pyplot as plt
plt.rcParams["figure.figsize"] = [24, 15]
from scipy.signal import savgol_filter
import matplotlib.dates as mdates
import matplotlib as mpl
from matplotlib.dates import MO, TU, WE, TH, FR, SA, SU
import locale, os, sys
import datetime
from datetime import date
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

root_path = sys.argv[1]
date_str = "{:%B %d, %Y %I:%M%p}".format(datetime.datetime.now())
d1 = date(2020, 1, 20)
d2 = date.today()
date_tick_interval = (d2-d1).days//105

df_confirmed = pd.read_csv("https://github.com/CSSEGISandData/COVID-19/raw/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv")


df_confirmed.drop(['UID', 'iso2', 'iso3', 'code3', 'Country_Region', 'Lat', 'Long_', 'Combined_Key'], axis=1, inplace=True)


fixed_cols = ['FIPS', 'Admin2', 'Province_State']


df_confirmed = pd.melt(frame=df_confirmed,id_vars=fixed_cols, var_name="rpt_date", value_name="confirmed")


df_confirmed.head(1000)

df_confirmed['daily_new'] = 0

df_confirmed['rpt_date'] = pd.to_datetime(df_confirmed.rpt_date, format="%m/%d/%y")

df_confirmed.sort_values(by=['Province_State', 'Admin2', 'rpt_date'], axis=0, inplace=True, ascending=[True, True,True])
df_confirmed = df_confirmed.reset_index(drop=True)

for idx, row in df_confirmed.iterrows():
    if idx > 0:
        prev_row = df_confirmed.loc[idx-1]
        if row['Admin2'] == prev_row['Admin2'] and row['Province_State'] == prev_row['Province_State']:
            df_confirmed.at[idx,'daily_new'] = row.confirmed - prev_row.confirmed

df_confirmed.info()

df_dead = pd.read_csv("https://github.com/CSSEGISandData/COVID-19/raw/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_US.csv")
df_dead.drop(['UID', 'iso2', 'iso3', 'code3', 'Country_Region', 'Lat', 'Long_', 'Combined_Key', 'Population'], axis=1, inplace=True)
df_dead = pd.melt(frame=df_dead,id_vars=fixed_cols, var_name="rpt_date", value_name="deaths")

df_dead['daily_new'] = 0
df_dead['rpt_date'] = pd.to_datetime(df_dead.rpt_date, format="%m/%d/%y")
df_dead.sort_values(by=['Province_State', 'Admin2', 'rpt_date'], axis=0, inplace=True, ascending=[True, True,True])
df_dead = df_dead.reset_index(drop=True)

for idx, row in df_dead.iterrows():
    if idx > 0:
        prev_row = df_dead.loc[idx-1]
        if row['Admin2'] == prev_row['Admin2'] and row['Province_State'] == prev_row['Province_State']:
            df_dead.at[idx,'daily_new'] = row.deaths - prev_row.deaths

df_dead.info()

def build_xy(df):
    x = df[(df.rpt_date > datetime.datetime(2020, 1, 27))].rpt_date.unique()
    y = df[(df.rpt_date > datetime.datetime(2020, 1, 27))].groupby(df['rpt_date']).daily_new.sum()
    mySum = df.daily_new.sum()
    return x, y, mySum

def createBarChart(x, y, jurisdiction, isConfirmed, cum_total, file_path):
    # Set the font dictionaries (for plot title and axis titles)
    title_font = {'fontname':'Arial', 'size':'32', 'color':'black', 'weight':'bold',
              'verticalalignment':'bottom'} # Bottom vertical alignment for more space
    axis_font = {'fontname':'Arial', 'size':'18', 'weight':'bold', 'color':'blue'}

    fmt = mdates.DateFormatter('%Y-%m-%d')
    loc = mdates.WeekdayLocator(byweekday=MO, interval=date_tick_interval)

    ax = plt.axes()
    ax.xaxis.set_major_formatter(fmt)
    ax.xaxis.set_major_locator(loc)
    for tick in ax.xaxis.get_major_ticks():
        tick.label.set_fontsize(14) 
    for tick in ax.yaxis.get_major_ticks():
        tick.label.set_fontsize(14) 
    ax.yaxis.set_major_formatter(mpl.ticker.StrMethodFormatter('{x:,.0f}'))
    ax.set_facecolor('#ebebeb')
    ax.set_axisbelow(True)

    if isConfirmed:
        file_name = jurisdiction + "Confirmed.png"
        title2 = " - New Cases per Day"
        cum_str = '{:,}'.format(cum_total) + " cases"
    else:
        file_name = jurisdiction + "Deaths.png"
        title2 = " - Deaths per Day"
        cum_str = '{:,}'.format(cum_total) + " deaths"

    plt.title(jurisdiction + title2, **title_font)
    plt.ylabel("")
    plt.grid(color='white', linewidth=1)


    plt.bar(x, y, color='blue', width = 1.9)
    plt.axhline(0, color='blue')

    y2 = savgol_filter(y, 21, 2)
    ax.plot(x, y2, color='green', linewidth=5)

    fig = plt.figure(1)
    fig.text(.09,.02,"Cumulative:  " + cum_str + "\nUpdated:  " + date_str + "\nSource: Center for Systems Science and Engineering at Johns Hopkins University", **axis_font)
    fig.autofmt_xdate()

    file_name = os.path.join(file_path,file_name) 
    fig.savefig(file_name, dpi=100, facecolor='w', edgecolor='w',
        orientation='portrait', format="png",
        transparent=False, bbox_inches=None, pad_inches=0.1, metadata=None)
    plt.close()


print("creating bar charts ", datetime.datetime.now())

x, y, mySum = build_xy(df_confirmed)
createBarChart(x, y, "US", True, mySum, root_path)
x, y, mySum = build_xy(df_dead)
createBarChart(x, y, "US", False, mySum, root_path)

print("finished US charts ", datetime.datetime.now())

for state_name in df_confirmed.Province_State.unique():
    df_state_confirmed = df_confirmed[df_confirmed['Province_State'] == state_name]
    x, y, mySum = build_xy(df_state_confirmed)
    createBarChart(x, y, state_name, True, mySum, root_path)
    df_state_dead = df_dead[df_dead['Province_State'] == state_name]
    x, y, mySum = build_xy(df_state_dead)
    createBarChart(x, y, state_name, False, mySum, root_path)
    
    myDir = os.path.join(root_path,state_name)
    if not os.path.isdir(myDir):
        os.makedirs(myDir)
    
    for county_name in df_state_confirmed.Admin2.unique():
        if isinstance(county_name, str):
            df_county_confirmed = df_state_confirmed[df_state_confirmed['Admin2'] == county_name]
            x, y, mySum = build_xy(df_county_confirmed)
            createBarChart(x, y, county_name, True, mySum, myDir)
            df_county_dead = df_state_dead[df_state_dead['Admin2'] == county_name]
            x, y, mySum = build_xy(df_county_dead)
            createBarChart(x, y, county_name, False, mySum, myDir)

print("finished python job ", datetime.datetime.now())





