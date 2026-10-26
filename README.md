# NovaLeague – Laboratorio de red (containerlab)

Este repositorio contiene la maqueta de red del caso NovaLeague. La usaréis para validar el diseño de los
entregables y, en el E5, para monitorizarla. No hace falta instalar nada: todo funciona en el navegador
con GitHub Codespaces.

## 1. Puesta en marcha (una sola vez)

1. Cread una cuenta en GitHub si no tenéis (podéis solicitar el pack de estudiante en GitHub Education).
2. Un miembro del grupo crea una copia del repositorio: botón **Use this template → Create a new repository**.
   Añadid al resto del grupo como colaboradores.
3. En vuestro repositorio: **Code → Codespaces → Create codespace on main**. Tarda unos minutos la primera vez.
4. Se abre VS Code en el navegador con un terminal Linux. Todo lo que sigue se escribe en ese terminal.

> **Horas gratuitas.** El Codespace usa una máquina de 4 cores, que consume vuestras horas gratuitas
> mensuales. **Paradlo cuando no lo uséis** (menú de Codespaces → *Stop codespace*). Se detiene solo tras
> 30 minutos sin actividad.

## 2. Desplegar la maqueta del E1

```bash
cd e1
sudo containerlab deploy -t e1.clab.yml --max-workers 1   # crea los equipos de uno en uno (4-5 minutos)
sudo containerlab inspect -t e1.clab.yml     # lista los equipos y sus IP de gestión
bash check.sh                                # comprueba qué funciona y qué falta
```

Para destruirla: `sudo containerlab destroy -t e1.clab.yml --cleanup`.

La topología está descrita en `e1/e1.clab.yml` y el esquema aparece al principio de ese fichero.
También la podéis ver gráficamente: `sudo containerlab graph -t e1.clab.yml`.

| Equipo | Qué es | Sistema |
|---|---|---|
| core1, core2 | Núcleo/distribución, gateway redundante (anycast) | Nokia SR Linux |
| acc-of | Acceso de una planta de oficinas | Nokia SR Linux |
| acc-lab | Acceso del Performance Lab | Nokia SR Linux |
| pc-staff, pc-tec, sala1-pc, sala2-pc | Ordenadores de usuario | Linux |

## 3. Qué viene configurado y qué tenéis que hacer vosotros

**Configurado como ejemplo (VLAN 10, staff):** el trunk de acc-of hacia los dos core, el puerto de
pc-staff y el gateway redundante en core1 y core2: los dos responden a la misma IP (10.100.10.1) y MAC
(**gateway anycast**, activo-activo). Cada core tiene además su propia IP (.2 y .3).

> **¿Y VRRP?** SR Linux en esta maqueta no incluye VRRP. En vuestro documento podéis proponer VRRP o HSRP; en la
> maqueta la redundancia del gateway se demuestra con anycast, la técnica de los CPD con EVPN (E2).
Leed `e1/configs/*.cfg`: son los comandos que se aplican al arrancar cada equipo.

**A completar por el grupo:**
- VLAN 20 (técnicos) en acc-of y en los core, con su gateway anycast.
- Una VLAN por sala en acc-lab y en los core, con su gateway.
- Routing entre core1 y core2 (por ejemplo, OSPF sobre el enlace `ethernet-1/1`).
- ACL: las salas no se ven entre sí ni ven la red corporativa; los técnicos sí acceden a las salas.
- Adaptar el direccionamiento (10.100.0.0/16 en el ejemplo) al rango de vuestra ficha de grupo.

`check.sh` os dice qué pruebas pasan. Las de aislamiento deben **fallar** (es lo que queremos).

> **Por qué el enlace core1–core2 no lleva VLANs.** SR Linux es un sistema pensado para centros de datos y
> la maqueta no usa Spanning Tree. Si pasáis VLANs por ese enlace crearéis un bucle de nivel 2. En vuestro
> diseño real (el documento) sí debéis explicar cómo evitaríais los bucles (STP, MLAG, etc.).

## 4. Trabajar con un equipo SR Linux

```bash
ssh admin@clab-e1-core1          # contraseña: NokiaSrl1!
```

Dentro del equipo:

```text
show interface brief                       # estado de los puertos
show network-instance vlan10 bridge-table mac-table all
info interface irb0                        # IRB: IP propia y gateway anycast
enter candidate                            # modo configuración
set / interface ethernet-1/4 admin-state enable
diff                                       # qué vais a cambiar
commit now                                 # aplicar
quit
```

Para que vuestros cambios se conserven al volver a desplegar, copiadlos también al fichero `.cfg` del equipo.

## 5. Prueba de redundancia del gateway

1. En un terminal: `docker exec -it clab-e1-pc-staff ping 10.100.10.1`
2. En otro terminal, entrad en core1 y apagad el puerto hacia acc-of:
   `enter candidate` → `set / interface ethernet-1/2 admin-state disable` → `commit now`
3. Observad cuántos pings se pierden. core2 ya era gateway activo: acc-of solo tiene que reaprender la MAC del
   gateway por el puerto de core2. Volved a activar el puerto. Comparadlo con lo que tardaría VRRP (≈ 3 s).

Capturad estas pruebas para el anexo del entregable.

## 6. Problemas habituales

| Síntoma | Qué hacer |
|---|---|
| `deploy` falla al descargar imágenes | Volved a lanzarlo; la primera descarga es grande. |
| Un switch tiene todos los puertos `down` (`show interface brief`) | Su plano de datos no arrancó por falta de CPU. Comprobad `nproc` (debe ser 4); destruid y desplegad de nuevo con `--max-workers 1`. **No uséis `docker restart`**: borra los cables del lab. |
| El Codespace tiene 2 cores | Codespaces → Change machine type → 4-core. Con 2 cores no arrancan los 4 SR Linux. |
| `deploy` dice que un contenedor está parado (tras reiniciar el Codespace) | `sudo containerlab destroy -t e1.clab.yml --cleanup` y desplegad de nuevo. |
| El Codespace va muy lento o se queda sin memoria | Comprobad que no tenéis dos labs desplegados (`sudo containerlab inspect --all`). |
| Se han acabado las horas gratuitas | Avisad al profesor: hay alternativa en VM local o en el aula. |
| Algún equipo no aplica la configuración | `docker logs clab-e1-<equipo>` y revisad el `.cfg`. |
