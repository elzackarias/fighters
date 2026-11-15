# Pleito en la Vecindad — Plan de desarrollo

> Estado al 14-nov-2026: **Fase 1 completa.** Vertical slice jugable con placeholders
> (rectángulos de color). Prueba de humo: `godot --headless --path . res://tests/smoke_test.tscn`

## Estructura del proyecto

```
res://
├── assets/                     # Arte y audio (solo archivos fuente importados)
│   ├── sprites/fighters/{chavo,quico,don_ramon,nono}/
│   ├── sprites/stages/{patio,casaramon,acapulco}/
│   ├── sprites/ui/
│   ├── audio/{music,sfx}/
│   └── fonts/
├── resources/                  # Datos de balance (.tres) — se editan en el Inspector
│   ├── attacks/                # AttackData: daño, frames, hitbox
│   ├── fighters/               # FighterData: stats, color/sprites, ataques
│   └── levels/                 # LevelData: escenario, rival, dificultad IA
├── scenes/
│   ├── fighters/fighter.tscn   # Un solo luchador genérico (jugador y CPU)
│   ├── levels/fight_arena.tscn # Una arena reutilizada por los 3 niveles
│   └── ui/                     # main_menu, instructions, hud, victory_screen
├── scripts/                    # Espejo de scenes/ + data/ + autoload/ + ai/
└── tests/smoke_test.tscn       # CPU vs CPU recorriendo los 3 niveles
```

**Decisión clave:** todo es *data-driven*. Agregar un personaje = un `.tres` en
`resources/fighters/`. Agregar un nivel = un `.tres` en `resources/levels/` + una línea
en `GameManager.LEVELS`. No se duplica código ni escenas.

**Capas de física:** 1 world · 2 fighters · 3 hitbox · 4 hurtbox.
Hitbox (capa 3, máscara 4) detecta Hurtbox (capa 4). Los cuerpos solo chocan con el mundo;
la separación entre luchadores la hace `FightArena._keep_fighters_apart()`.

## Fases

### ✅ Fase 1 — Núcleo jugable (hecho)
- Fighter (CharacterBody2D): gravedad, caminar, salto, agacharse, 5 ataques, bloqueo
  alto/bajo, hitstun/blockstun, KO, buffer de entrada.
- AIController: FSM Idle/Chase/Attack/Block/Retreat, dificultad por nivel.
- FightArena: temporizador, KO, tiempo agotado, mejor de 3, puntaje.
- GameManager: flujo Menú → Instrucciones → 3 niveles → Victoria, fundidos, controles.
- HUD: barras de vida con daño retrasado, rounds, timer, pausa.

### Fase 2 — Arte y animación (1–2 semanas)
1. Definir estilo y tamaño (sugerido: pixel art ~128 px de alto; activar
   *Texture Filter = Nearest* en Configuración del proyecto).
2. Por personaje, crear un `SpriteFrames` con: `idle, walk, crouch, jump, block, hit, ko,
   victory, light_punch, heavy_punch, crouch_light, crouch_heavy, air_kick`.
   Asignarlo en `FighterData.sprite_frames`: el placeholder se oculta solo.
   Estructura: `resources/fighters/<id>/<id>.tres` + `<id>_frames.tres`.
   Hojas con fondo de color sólido: `python3 tools/slice_sheet.py tools/<id>_sheet.json`
   quita el fondo y genera el SpriteFrames con los frames alineados por los pies
   (ver `tools/quico_sheet.json`). Ajustar `FighterData.sprite_scale` a ~140 px de alto.
3. Ajustar `hitbox_offset/size` de cada AttackData para que calce con el dibujo
   (activar *Depurar > Formas de colisión visibles*).
4. Fondos 1280×720 por escenario → `LevelData.background_texture`.
5. Retratos de personajes para HUD y pantalla de "VS" antes de cada nivel.

### Fase 3 — Personalidad y game feel (1 semana)
1. **Movimiento especial por personaje** (lo que más diferencia a cada rival). Ej.:
   Chavo — torta (proyectil); Quico — berrinche (ráfaga); Don Ramón — sombrerazo;
   Ñoño — embestida. Implementar como `AttackData` + campo `special_attack` y un
   input simple (ligero+pesado a la vez).
2. Hitstop (congelar 3–5 frames al conectar), screen shake, partículas de impacto.
3. Efectos de sonido (golpe, bloqueo, KO, voz de anuncio) y música por escenario
   (`LevelData.music` ya está conectado).
4. Pantalla "VS" con `intro_quote` de cada personaje (ya existe en FighterData).

### Fase 4 — IA y balance (3–5 días)
1. Ajustar `ai_reaction_time / ai_aggression / ai_block_chance` por nivel jugando.
2. IA específica por rival (subclase de AIController o `@export` de patrones):
   Quico huye y molesta, Don Ramón presiona, Ñoño es lento pero pega fuerte.
3. Evitar que la IA sea "perfecta": ya tiene variación aleatoria; añadir errores a
   propósito en nivel 1.
4. Correr `tests/smoke_test.tscn` tras cada cambio de balance.

### Fase 5 — Pulido de UI y flujo (3–5 días)
1. Tema global (`Theme` .tres) con fuente propia para todos los menús.
2. Menú de pausa con "Reanudar / Reiniciar / Menú".
3. Opciones: volumen (buses Master/Música/SFX), pantalla completa.
4. Pantalla de victoria: animación, créditos, mensaje educativo final revisado.
5. Accesibilidad: remapeo de controles, modo fácil.

### Fase 6 — QA y entrega (3–5 días)
1. Checklist de pruebas: cada nivel ganado/perdido, tiempo agotado, empate,
   pausa durante mensajes, mando desconectado.
2. Rendimiento en el dispositivo objetivo.
3. Exportar (Proyecto > Exportar). **Si es para Web**, cambiar el renderer a
   *Compatibility* (`renderer/rendering_method="gl_compatibility"`).
4. Notas legales: personajes de *El Chavo del 8* son propiedad de sus titulares;
   uso educativo/no comercial.

## Extensiones opcionales
- Modo 2 jugadores local (el Fighter ya soporta `input_prefix = "p2_"`).
- Selección de personaje.
- Guardado de récord de puntaje (`user://save.cfg` con ConfigFile).
