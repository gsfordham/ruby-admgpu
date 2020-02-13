# ruby-amdgpu
This isn't the whole program, just a Ruby module from a program I wrote to control amdgpu drivers. I never really got around to optimizing it, but the whole program runs over websockets, so do with it what you will.

# Installation
I haven't yet made a gem for this, because I was actually planning to rewrite it, possibly in a faster language, but to make use of it, simply clone the repo or download the file ``gpuinfo.rb``

# Usage
1) Download the file/repo
1) Place a copy in the directory with the program that will be accessing it
1) Create a list of GPU objects
1) Make calls on each GPU object as desired/needed

# Notes
1) This library is NOT standalone and will not work without an actual Ruby program to execute the code within
1) This library interacts with Linux drivers, so it uses files in the kernel's ``/sys/`` virtual filesystem, so whatever program interacts with it **MUST** be running as ``root``
1) The output of the functions is a hash, so you should be prepared to work with a Ruby hash, whether you use it raw or change it to something like JSON, YAML, or XML (In my case, I made a Web UI, so I used JSON)

# Limiation of Liability
Yeah nah, I claim no liability. You can break your box by using it not as intendedor for the wrong cards, but I ain't fixing it or buying you a new one. Also, LGPLv3, as this is licensed, limits my liability anyway, so don't bother hiring a lawyer.