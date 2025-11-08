# AutoRig2D

## English

**AutoRig2D** is a Godot Engine plugin designed to radically simplify the 2D character rigging process. It provides a powerful suite of tools to automate the creation of skeletons, polygons, and skin weights directly from a character's sprite sheet.

### Core Features

*   **Automatic Polygon Generation:** Analyzes your character's sprite, identifies separate parts using a flood-fill algorithm, and generates optimized `Polygon2D` nodes.
    *   **Contour Simplification:** Uses the Ramer-Douglas-Peucker algorithm to reduce vertex count, controlled by an `Epsilon` slider for fine-tuning.
    *   **Smart Intersection Handling:** Automatically detects overlapping areas between related body parts (e.g., torso and arm) and generates "overlap" polygons to ensure smooth, organic-looking deformations at the joints.

*   **Humanoid Skeleton Builder:** Constructs a complete, hierarchical `Skeleton2D` based on simple "seed" markers you place on the character.
    *   **Heuristic-Based Structure:** Intelligently creates bones for limbs, a central pelvis, and a multi-bone spine for natural torso movement.
    *   **Automatic Hierarchy:** Correctly parents bones based on humanoid anatomy (e.g., arms connect to the upper spine, legs connect to the pelvis).

*   **Automatic Weight Painting (Skinning):** Calculates and assigns skin weights for each vertex of the generated polygons.
    *   **Gaussian Falloff:** Influence is calculated based on the distance from a vertex to a bone segment, creating smooth and natural-looking influence gradients.
    *   **Multi-Bone Influence:** Each vertex is influenced by the most relevant nearby bones (up to 3), ensuring seamless transitions at joints.

*   **Integrated Editor UI:** A simple, intuitive dock in the Godot editor guides you through the entire process, from loading your sprite to generating the final rig.

### How to Use

1.  **Installation:**
    *   Copy the `addons/autorig2d` folder into your Godot project's `addons` directory.
    *   Go to `Project > Project Settings > Plugins` and enable the "AutoRig2D" plugin.

2.  **Rigging Process:**
    *   A new dock named "AutoRig2D" will appear in the editor.
    *   **Load Atlas:** Click "Select Atlas" and choose your character's sprite sheet (PNG with transparency). The sprite will appear in the dock.
    *   **Define Parts:** The plugin starts with a default list of humanoid parts (`torso`, `head`, etc.). You can add your own custom parts using the "Add New Part" button.
    *   **Place Seeds:** Select a part from the dropdown menu (e.g., `left_arm`). Click on the image to place "seeds" (markers). For limbs, place seeds in pairs to define a bone (e.g., one at the shoulder, one at the elbow; one at the elbow, one at the wrist). The first seed for a part also acts as its pivot point.
    *   **Generate Preview:** Once seeds are placed, click **"Generate Preview"**. This will:
        1.  Generate all `Polygon2D` nodes.
        2.  Build the `Skeleton2D`.
        3.  Link them together in your scene under a new `GeneratedRigRoot` node.
    *   **Generate Weights:** If you are satisfied with the preview, click **"Generate Weights"**. This will perform the automatic skinning process, making the rig ready for animation.

---

## Español

**AutoRig2D** es un plugin para Godot Engine diseñado para simplificar radicalmente el proceso de rigging de personajes 2D. Proporciona un potente conjunto de herramientas para automatizar la creación de esqueletos, polígonos y pesos de pintado (skinning) directamente desde la hoja de sprites de un personaje.

### Funcionalidades Principales

*   **Generación Automática de Polígonos:** Analiza el sprite de tu personaje, identifica las partes separadas usando un algoritmo de "flood-fill" y genera nodos `Polygon2D` optimizados.
    *   **Simplificación de Contornos:** Utiliza el algoritmo Ramer-Douglas-Peucker para reducir el número de vértices, controlado por un slider `Epsilon` para un ajuste fino.
    *   **Gestión Inteligente de Intersecciones:** Detecta automáticamente las áreas de solapamiento entre partes del cuerpo relacionadas (ej. torso y brazo) y genera polígonos de "unión" para asegurar deformaciones suaves y orgánicas en las articulaciones.

*   **Constructor de Esqueletos Humanoides:** Construye un `Skeleton2D` completo y jerárquico a partir de simples marcadores ("semillas") que colocas sobre el personaje.
    *   **Estructura Basada en Heurísticas:** Crea de forma inteligente huesos para las extremidades, una pelvis central y una espina dorsal multi-hueso para un movimiento natural del torso.
    *   **Jerarquía Automática:** Emparenta los huesos correctamente basándose en la anatomía humanoide (ej. los brazos se conectan a la parte superior de la espina, las piernas a la pelvis).

*   **Pintado de Pesos Automático (Skinning):** Calcula y asigna los pesos de influencia para cada vértice de los polígonos generados.
    *   **Influencia Gaussiana:** La influencia se calcula basándose en la distancia de un vértice a un segmento de hueso, creando gradientes de influencia suaves y de aspecto natural.
    *   **Influencia Multi-Hueso:** Cada vértice es influenciado por los huesos cercanos más relevantes (hasta 3), garantizando transiciones perfectas en las articulaciones.

*   **UI Integrada en el Editor:** Un panel simple e intuitivo en el editor de Godot te guía a través de todo el proceso, desde cargar tu sprite hasta generar el rig final.

### Cómo Usar

1.  **Instalación:**
    *   Copia la carpeta `addons/autorig2d` en el directorio `addons` de tu proyecto de Godot.
    *   Ve a `Proyecto > Ajustes del Proyecto > Plugins` y activa el plugin "AutoRig2D".

2.  **Proceso de Rigging:**
    *   Aparecerá un nuevo panel llamado "AutoRig2D" en el editor.
    *   **Cargar Atlas:** Haz clic en "Seleccionar Atlas" y elige la hoja de sprites de tu personaje (PNG con transparencia). El sprite aparecerá en el panel.
    *   **Definir Partes:** El plugin incluye una lista de partes humanoides por defecto (`torso`, `head`, etc.). Puedes añadir tus propias partes personalizadas con el botón "Añadir Nueva Parte".
    *   **Colocar Semillas:** Selecciona una parte del menú desplegable (ej. `left_arm`). Haz clic en la imagen para colocar "semillas" (marcadores). Para las extremidades, coloca las semillas en pares para definir un hueso (ej. una en el hombro, otra en el codo; una en el codo, otra en la muñeca). La primera semilla de una parte también actúa como su punto de pivote.
    *   **Generar Previsualización:** Una vez colocadas las semillas, haz clic en **"Generar Previsualización"**. Esto hará lo siguiente:
        1.  Generará todos los nodos `Polygon2D`.
        2.  Construirá el `Skeleton2D`.
        3.  Los enlazará en tu escena bajo un nuevo nodo `GeneratedRigRoot`.
    *   **Generar Pesos:** Si estás satisfecho con la previsualización, haz clic en **"Generar Pesos"**. Esto realizará el proceso de skinning automático, dejando el rig listo para animar.