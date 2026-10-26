#!/usr/bin/env bash
# Comprobaciones básicas de la topología base del E1.
# Uso: bash check.sh   (con el lab desplegado)

LAB=e1
ok=0; ko=0

ping_test() {  # origen destino descripción
  if docker exec "clab-$LAB-$1" ping -c 3 -W 1 "$2" >/dev/null 2>&1; then
    echo "  OK   $3"; ok=$((ok+1))
  else
    echo "  FALLO $3"; ko=$((ko+1))
  fi
}

echo "VLAN 10 (ejemplo completo):"
ping_test pc-staff 10.100.10.1 "pc-staff -> gateway anycast (10.100.10.1)"
ping_test pc-staff 10.100.10.2 "pc-staff -> core1 (10.100.10.2)"
ping_test pc-staff 10.100.10.3 "pc-staff -> core2 (10.100.10.3)"

echo "Lo que tenéis que hacer funcionar vosotros:"
ping_test pc-tec   10.100.20.1  "pc-tec -> gateway VLAN 20"
ping_test sala1-pc 10.100.101.1 "sala1-pc -> gateway sala 1"
ping_test sala2-pc 10.100.102.1 "sala2-pc -> gateway sala 2"
ping_test pc-tec   10.100.101.11 "pc-tec -> sala1-pc (debe FUNCIONAR: acceso técnico)"

echo "Aislamiento (estas pruebas deben FALLAR para que el diseño sea correcto):"
for pair in "sala1-pc 10.100.102.11 sala1-pc->sala2-pc" "pc-staff 10.100.101.11 pc-staff->sala1-pc"; do
  set -- $pair
  if docker exec "clab-$LAB-$1" ping -c 2 -W 1 "$2" >/dev/null 2>&1; then
    echo "  FALLO $3 tiene conectividad (no debería)"; ko=$((ko+1))
  else
    echo "  OK   $3 bloqueado"; ok=$((ok+1))
  fi
done

echo; echo "Resultado: $ok correctas, $ko pendientes o incorrectas"
