# cupd-wrap
Wrapper for Arch Linux's checkupdate tool

This is a simple script that refines the output of checkupdates and
grabs the latest news from the Arch RSS news feed. The idea is to
have some extra info before commiting to grabbing a fresh copy
of the package database via pacman -Sy.

You can also pass it a "news" argument (i.e., "bash cupd-wrap.bash news")
just to get the news.

Prerequisites: checkupdates (included in pacman-contrib), xmllint (in libxml2).

Use at your own risk.
