#!/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:~/bin:/usr/bin:/bin:/usr/sbin:/sbin
R CMD BATCH covid-19.R
mv covid-19.Rout /config/covid-19.Rout
