
if exists("did_restart_menu_trans")
    finish
endif
let did_restart_menu_trans = 1
let s:save_cpo = &cpo
set cpo&vim

scriptencoding utf-8

menutrans &Restart<Tab>:Restart  再起動(&R)<Tab>:Restart


let &cpo = s:save_cpo
unlet s:save_cpo
