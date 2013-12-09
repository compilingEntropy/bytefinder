bytefinder
===========

Given a file and a mutated version of that file that crashes MobileSafari, this finds the bytes that cause the mutated version to crash MobileSafari.

What it does:  
This will generate a file where the only differences remaining between it and the original are the differences required to cause a crash. It will also give you the offsets of those differences and what they are. Depends on https://github.com/uroboro/hexdiff/

How it works:  
Soooo complicated. I'll probably do a blogpost or something.  
No network connection is required. You should, however, start and stop the script over ssh (rather than mobileterminal) to avoid confusing the device as it does its work.

Always remember: Before you begin fuzzing, go to 'Settings' > 'General' > 'About' > 'Diagnostics & Usage' and check the "Don't Send" option. Otherwise, all your hard work will go to Apple and you will be sad. =(

Usage:  `finder.sh -f ./original.mov -m ./mutated.mov [-t 11] [-q]`