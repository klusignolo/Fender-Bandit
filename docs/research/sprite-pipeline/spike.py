# Research spike for #6 (throwaway, not production code).
# Builds a primitive car, renders it in 8 directions with a 2:1 dimetric ortho camera
# (and once top-down), Workbench + inverted-hull outline, transparent PNG, then packs a
# horizontal sheet with Blender's bundled numpy. Tested on Blender 5.2.1 LTS, Windows.
#
#   blender -b --factory-startup -P spike.py -- <out_dir>
import bpy, math, os, sys, time
import numpy as np

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)  # Workbench "Material" colour
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)  # EEVEE
    return m

# Turntable root: rotate the model, not the camera, so the light stays fixed in the world.
root = bpy.data.objects.new("Root", None); scn.collection.objects.link(root)
body, glass, tyre = mat("Body", (0.85, 0.15, 0.1)), mat("Glass", (0.2, 0.3, 0.45)), mat("Tyre", (0.05, 0.05, 0.05))

def box(size, loc, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.scale = size; o.data.materials.append(m); o.parent = root

box((1.9, 1.0, 0.35), (0, 0, 0.3), body)       # 1.9 x 1.0 ~ the greybox's 38 x 20 px
box((0.9, 0.85, 0.3), (-0.1, 0, 0.62), glass)
for x in (0.6, -0.6):
    for y in (0.5, -0.5):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.16, depth=0.12,
                                            location=(x, y, 0.16), rotation=(math.pi / 2, 0, 0))
        w = bpy.context.object; w.data.materials.append(tyre); w.parent = root

# Inverted-hull outline: flipped-normal Solidify shell in a back-face-culled black material.
ink = mat("Ink", (0, 0, 0)); ink.use_backface_culling = True
for o in root.children:
    o.data.materials.append(ink)
    s = o.modifiers.new("Hull", 'SOLIDIFY')
    s.thickness, s.offset, s.use_flip_normals = 0.04, 1, True
    s.material_offset = len(o.data.materials) - 1

cam_data = bpy.data.cameras.new("Cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 2.6
cam = bpy.data.objects.new("Cam", cam_data); scn.collection.objects.link(cam); scn.camera = cam

def camera_iso(elev_deg=30.0, azim_deg=45.0, dist=20.0):
    # 2:1 pixel dimetric = 30 deg elevation (X rotation 60), 45 deg azimuth.
    # True isometric would be elevation 35.264 deg (X rotation 54.736), a 1.73:1 diamond.
    el, az = math.radians(elev_deg), math.radians(azim_deg)
    cam.rotation_euler = (math.radians(90 - elev_deg), 0, az)
    cam.location = (dist * math.cos(el) * math.sin(az), -dist * math.cos(el) * math.cos(az), dist * math.sin(el))

def camera_top(dist=20.0):
    cam.rotation_euler = (0, 0, 0); cam.location = (0, 0, dist)

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.rotation_euler = (math.radians(40), 0, math.radians(-30)); scn.collection.objects.link(sun)
scn.world = bpy.data.worlds.new("World")

r = scn.render
r.engine = 'BLENDER_WORKBENCH'                # 'BLENDER_EEVEE' in 5.x (was BLENDER_EEVEE_NEXT in 4.2-4.5)
r.resolution_x = r.resolution_y = 128
r.film_transparent = True                     # alpha background
r.image_settings.file_format = 'PNG'; r.image_settings.color_mode = 'RGBA'
scn.view_settings.view_transform = 'Standard' # not AgX/Filmic: keep palette colours exact
sh = scn.display.shading
sh.light, sh.color_type = 'STUDIO', 'MATERIAL'
sh.show_backface_culling = True               # needed for the hull in Workbench
sh.show_object_outline = True
scn.display.render_aa = '8'

def render_dirs(tag, n=8):
    paths, t0 = [], time.perf_counter()
    for i in range(n):
        root.rotation_euler = (0, 0, i * 2 * math.pi / n)
        r.filepath = os.path.join(out, f"{tag}_{i}.png")
        bpy.ops.render.render(write_still=True)
        paths.append(r.filepath)
    print(f"TIME {tag}: {(time.perf_counter() - t0) * 1000 / n:.0f} ms/frame")
    return paths

def pack(paths, dst, cols):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size; rows = math.ceil(len(imgs) / cols)
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for k, im in enumerate(imgs):
        px = np.empty(w * h * 4, dtype=np.float32); im.pixels.foreach_get(px)
        rr = rows - 1 - k // cols                  # Blender pixel rows run bottom-up
        sheet[rr * h:(rr + 1) * h, (k % cols) * w:(k % cols + 1) * w] = px.reshape(h, w, 4)
    img = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    img.pixels.foreach_set(sheet.ravel()); img.filepath_raw = dst; img.file_format = 'PNG'; img.save()

camera_iso(); pack(render_dirs("iso"), os.path.join(out, "car_iso_8dir.png"), 8)
camera_top(); render_dirs("top", 1)
