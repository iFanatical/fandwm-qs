## fandwm-qs
  
<img width="1919" height="1080" alt="2026-07-11-210108_screenshotcmd" src="https://github.com/user-attachments/assets/ab12ef6d-bdbf-4f29-8492-3393ba1acd87" />
  
git clone https://github.com/ifanatical/fandwm-qs.git  
cd fandwm-qs  
make && sudo make install  
  
Requirements:  
sxhkd (hotkeys independent of dwm)  
Qt 6 base + libpulse (bar — `dwm-qs-shell`, built by make)  
  
The bar is a hand-rolled C++/Qt panel (`shell/`); see QUICKSHELL.md for the
full docs. QuickShell is no longer required — the original QML config it was
ported from is kept in `quickshell/` for reference.  
  
Launch from `~/.xinitrc`:  

dwm-qs-shell --no-duplicate &  
exec dwm-qs  
