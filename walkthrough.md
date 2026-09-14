# Walkthrough: Dominó Score en Flutter

Se ha transformado completamente el miniproyecto web (**HTML5 + Tailwind CSS + Vanilla JS**) en una **aplicación móvil moderna construida con Flutter**, manteniendo exactamente la misma estética elegante en modo oscuro (`Slate-950`), la paleta de colores y toda la lógica de cálculo y persistencia.

---

## 📱 Comparativa de Componentes (Web vs Flutter)

| Componente Web Original | Equivalente en Flutter | Archivo |
| :--- | :--- | :--- |
| **Encabezado** (`<header>`, icono de dado, título y botón de Meta) | `HeaderWidget` con badge de meta interactivo y estilo card slate-900 | [header_widget.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/header_widget.dart) |
| **Marcadores de Equipos** (Grid 2 cols, Pareja 1 en Esmeralda, Pareja 2 en Índigo, nombres editables y totales) | `TeamCardWidget` con `TextField` reactivo, contador de rondas y botón de acción con feedback visual | [team_card_widget.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/team_card_widget.dart) |
| **Modal Sumar / Editar Puntos** (Entrada numérica, botones rápidos `+10, +20, +30, +50`, botón eliminar y cancelar) | `PointsDialog` con teclado numérico optimizado para móviles, chips de suma rápida y eliminación en modo edición | [points_dialog.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/points_dialog.dart) |
| **Historial de Rondas** (Lista inversa de manos, badge de 'En juego' / '¡Ganó!', edición al tocar cualquier ronda) | `RoundsHistoryWidget` con `ListView.separated` interactivo, tags coloreados por equipo y detector de toques | [rounds_history_widget.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/rounds_history_widget.dart) |
| **Configuración de Meta** (`prompt` de navegador) | `SettingsDialog` moderno con chips de selección rápida (`100, 150, 200, 300, 500`) y campo personalizado | [settings_dialog.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/settings_dialog.dart) |
| **Reinicio de Partida** (`confirm` de JS con estilos Rose) | `ResetConfirmDialog` con advertencia visual y botón de confirmación en color `Rose-600` | [reset_dialog.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/reset_dialog.dart) |
| **Condición de Victoria** (Texto en el historial) | `WinnerDialog` mejorado: modal con copa de victoria dorada, desglose del marcador final y botón para nueva partida | [winner_dialog.dart](file:///c:/Users/DELL/Desktop/domino/lib/widgets/winner_dialog.dart) |
| **Persistencia** (`localStorage.setItem('domino_score')`) | `GameState` con persistencia nativa mediante `SharedPreferences` y reactividad con `ChangeNotifier` | [game_state.dart](file:///c:/Users/DELL/Desktop/domino/lib/models/game_state.dart) |

---

## 📂 Estructura Generada en el Workspace

El proyecto se encuentra listo en [c:/Users/DELL/Desktop/domino](file:///c:/Users/DELL/Desktop/domino):

```
c:/Users/DELL/Desktop/domino/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── theme/
│   │   └── app_colors.dart
│   ├── models/
│   │   ├── round.dart
│   │   └── game_state.dart
│   └── widgets/
│       ├── header_widget.dart
│       ├── team_card_widget.dart
│       ├── rounds_history_widget.dart
│       ├── points_dialog.dart
│       ├── settings_dialog.dart
│       ├── reset_dialog.dart
│       └── winner_dialog.dart
└── web/
    └── index.html
```

---

## 🚀 Cómo ejecutar la aplicación

Para ejecutar la aplicación una vez tengas el SDK de Flutter configurado en tu terminal:

```bash
cd C:\Users\DELL\Desktop\domino
flutter pub get
flutter run
```

Si deseas probarla de inmediato en el navegador:
```bash
flutter run -d chrome
```
O compilarla para Android (APK):
```bash
flutter build apk --release
```
