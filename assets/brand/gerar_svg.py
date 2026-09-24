"""Generate the RotaSaúde vector logo family from the supplied black trace."""

from html import escape
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / 'assets/brand/originais/rota-saude-vetor-black.svg'
OUTPUT = REPO / 'assets/brand/svg'
SVG_NS = '{http://www.w3.org/2000/svg}'
TRACE = ET.parse(SOURCE).getroot().find(f'.//{SVG_NS}path').attrib['d']
TRANSFORM = 'translate(120.5 161.5) scale(0.79)'
BLUE = '#0D74C8'
TEAL = '#06A8AB'
NAVY = '#12466A'
SLOGAN_NAVY = '#15344F'

PRODUCTS = {
    'icone': ('Ícone', '435 162 383 482', True, False, False),
    'logo-completa': ('Logo completa', '128 162 1000 719', True, True, True),
    'somente-nome': ('Somente nome', '128 620 1000 185', False, True, False),
    'icone-nome': ('Ícone e nome sem slogan', '128 162 1000 643', True, True, False),
    'somente-slogan': ('Somente slogan', '128 807 1000 60', False, False, True),
}
VARIANTS = {
    'colorida-original': None,
    'colorida-cores-secundarias': None,
    'preto': '#000000',
    'branco': '#FFFFFF',
    'azul': BLUE,
    'verde': TEAL,
}
REGIONS = {
    'icone': (400, 0, 500, 600),
    'logo-completa': (0, 0, 1254, 900),
    'somente-nome': (0, 600, 1254, 215),
    'icone-nome': (0, 0, 1254, 815),
    'somente-slogan': (0, 815, 1254, 85),
    'rota': (0, 600, 563, 215),
    'saude': (563, 600, 691, 215),
}


def inkscape_action(input_path, output_path, action):
    subprocess.run(
        ['inkscape', str(input_path),
         f'--actions=select-all;{action};export-filename:{output_path};export-do'],
        check=True, capture_output=True, text=True,
    )
    if not output_path.exists():
        raise RuntimeError(f'Inkscape did not create {output_path}')
    return ET.parse(output_path).getroot()


def crop_trace(rect, temp_dir, label):
    x, y, w, h = rect
    input_path = temp_dir / f'{label}-input.svg'
    output_path = temp_dir / f'{label}-output.svg'
    input_path.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="1254" height="1254" '
        'viewBox="0 0 1254 1254">'
        f'<path d="{escape(TRACE, quote=True)}"/>'
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}"/>'
        '</svg>', encoding='utf-8',
    )
    root = inkscape_action(input_path, output_path, 'path-intersection')
    paths = root.findall(f'.//{SVG_NS}path')
    if len(paths) != 1:
        raise RuntimeError(f'Expected one cropped path for {label}; got {len(paths)}')
    return paths[0].attrib['d']


def icon_parts(temp_dir):
    broken_path = temp_dir / 'broken.svg'
    root = inkscape_action(SOURCE, broken_path, 'path-break-apart')
    parts = {path.attrib['id']: path.attrib['d']
             for path in root.findall(f'.//{SVG_NS}path')}
    required = {'path71', 'path73', 'path72', 'path70', 'path69', 'path74', 'path68'}
    if not required <= parts.keys():
        raise RuntimeError('The icon contours have changed in the source SVG')
    return parts


def path_element(data, color):
    return f'<path fill="{color}" d="{escape(data, quote=True)}"/>'


def make_svg(product, variant, cropped, parts):
    label, viewbox, has_icon, has_name, has_slogan = PRODUCTS[product]
    _, _, width, height = viewbox.split()
    title = f'{label} — {variant.replace("-", " ")}'
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="{viewbox}" role="img" aria-labelledby="title">',
        f'<title id="title">{escape(title)}</title>',
        f'<g transform="{TRANSFORM}">',
    ]
    monochrome = VARIANTS[variant]
    if monochrome:
        lines.append(path_element(cropped[product], monochrome))
    else:
        secondary = variant == 'colorida-cores-secundarias'
        icon_primary = TEAL if secondary else BLUE
        icon_accent = BLUE if secondary else TEAL
        name_accent = TEAL if secondary else BLUE
        if has_icon:
            for ident in ('path71', 'path73', 'path72', 'path70', 'path69', 'path74', 'path68'):
                color = icon_accent if ident in ('path74', 'path68') else icon_primary
                lines.append(path_element(parts[ident], color))
        if has_name:
            lines.append(path_element(cropped['rota'], NAVY))
            lines.append(path_element(cropped['saude'], name_accent))
        if has_slogan:
            lines.append(path_element(cropped['somente-slogan'], SLOGAN_NAVY))
    lines += ['</g>', '</svg>']
    return '\n'.join(lines) + '\n'


def main():
    with TemporaryDirectory() as directory:
        temp_dir = Path(directory)
        parts = icon_parts(temp_dir)
        cropped = {label: crop_trace(rect, temp_dir, label)
                   for label, rect in REGIONS.items()}
    for product in PRODUCTS:
        folder = OUTPUT / product
        folder.mkdir(parents=True, exist_ok=True)
        for variant in VARIANTS:
            (folder / f'{variant}.svg').write_text(
                make_svg(product, variant, cropped, parts), encoding='utf-8')
    print(f'Generated {len(PRODUCTS) * len(VARIANTS)} SVG files in {OUTPUT}')


if __name__ == '__main__':
    main()
