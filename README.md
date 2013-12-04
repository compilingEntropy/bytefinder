fuzzycactus
===========

Given a file and a mutated version of that file...

What it does:  
This tool can turn anyone's freshly jailbroken device into a fuzzing machine in minutes. All the setup is handled for you.

How it works:  
Soooo complicated. I'll probably do a blogpost or something.  
No network connection is required. You should, however, start and stop the script over ssh (rather than mobileterminal) to avoid confusing the device as it does its work. Once the script is started you can safely disconnect.

Always remember: Before you begin fuzzing, go to 'Settings' > 'General' > 'About' > 'Diagnostics & Usage' and check the "Don't Send" option. Otherwise, all your hard work will go to Apple and you will be sad. =(

Usage:  `finder.sh -f ./original.mov -m ./mutated.mov [-t 11]`