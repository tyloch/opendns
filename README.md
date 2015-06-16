# opendns
Control OpenDNS by Time

* opendns.pl -- default script
* content.conf -- default settings for lock of sites
* opendns.conf -- default config

in opendns.conf you have section networks:
1st lev, you need id from your setting, e.g. if your link https://dashboard.opendns.com/settings/1234321/content_filtering then your id is 1234321
2nd level, have date and time for update default rules (see content.conf)
e.g. we reset rules to default via for empty section
```
<1234567-7>
</1234567-7>
```
where first group of numbers is days of week (1 - mon, .. 7 - sun), second group is hour for rule (7 - am)

if section is not empty we have two number, first is id of category (see full list in content.conf or via developer tool on page id of checkbox in settings page), second number is 1 - on or  0 - off 
e.g. blocks of social network in mon..fri start with 12:00
```
<12345-12>	# mon-fri 12:00
			24	1	# Disallow Social Networking
</12345-12>
```

We update opendns setting every hour at 1 and 8 min.
```
 $ crontab -l
 1,8	*	*	*	*	/home/lsopov/tools/opendns/opendns.pl
```
