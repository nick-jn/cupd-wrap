# cupd-wrap
Wrapper for Arch Linux's checkupdate tool

This script refines the output of checkupdates and grabs
the latest news from the Arch RSS news feed. The idea is to
have some extra info before commiting to grabbing a fresh copy
of the package database via pacman -Sy.

    Usage: cupd-wrap [ARG]=[SINGLE SUB-ARG]
    
    ARGS      SUB-ARGS (first is default)
    =====================================
    news      normal - news are displayed along with updates
              only   - display news and quit
              nil    - do not display news along with updates
    
    syu       prompt   - display a (y/N) prompt before launching "sudo pacman -Syu"
              noprompt - launch "sudo pacman -Syu" without a (y/N) prompt
              nil      - do not launch "sudo pacman -Syu"
    
    pacfiles  nil    - do not search for *.pacsave/*.pacnew files in /
              find   - use find to search for *.pacsave/*.pacnew files in /
              locate - use locate to search for *.pacsave/*.pacnew files in /
    
    Examples:
    cupd-wrap syu=noprompt pacfiles=locate
    cupd-wrap news=nil syu=nil

Prerequisites:
==============
checkupdates (in pacman-contrib), xmllint (in libxml2).

Serving suggestions:
====================
With "news=only" it can be used as just a news fetcher.

Passing "news=nil syu=nil" will print an enriched output of checkupdates. You can easily
grep for package names, repo names, number of packages, versions, total download size.

Use at your own risk.