## fandwm-qs
  
<img width="1919" height="1080" alt="2026-07-11-210108_screenshotcmd" src="https://github.com/user-attachments/assets/ab12ef6d-bdbf-4f29-8492-3393ba1acd87" />
  
git clone https://github.com/ifanatical/fandwm-qs.git  
cd fandwm-qs  
make && sudo make install  
  
Requirements:  
sxhkd (hotkeys independent of dwm)  
quickshell (bar)  
  
I have my quickshell directory here (../fandwm-qs/quickshell) symlinked to ~/.config/quickshell.  
If you want a similar setup, so everything lives within the git repo, you can run the following command:  

ln -s /path/to/fandwm-qs/quickshell $HOME/.config/quickshell  
