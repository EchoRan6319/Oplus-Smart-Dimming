SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

print_modname() {
  ui_print "*******************************"
  ui_print "      欧加真智能调光"
  ui_print "  Native daemon debug build"
  ui_print "*******************************"
}

on_install() {
  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2
}

set_permissions() {
  set_perm "$MODPATH" 0 0 0755

  [ -f "$MODPATH/module.prop" ] && set_perm "$MODPATH/module.prop" 0 0 0644
  [ -f "$MODPATH/customize.sh" ] && set_perm "$MODPATH/customize.sh" 0 0 0644
  [ -d "$MODPATH/META-INF" ] && set_perm_recursive "$MODPATH/META-INF" 0 0 0755 0644
  [ -d "$MODPATH/icons" ] && set_perm_recursive "$MODPATH/icons" 0 0 0755 0644

  if [ -d "$MODPATH/bin" ]; then
    set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
  fi

  if [ -d "$MODPATH/scripts" ]; then
    set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
  fi

  [ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
  [ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
  [ -f "$MODPATH/bin/oplus_smart_dimmingd" ] && set_perm "$MODPATH/bin/oplus_smart_dimmingd" 0 0 0755
}
