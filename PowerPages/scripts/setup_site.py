#!/usr/bin/env python3
"""
Setup the Nintex eSign Power Pages site with GC Bootstrap 5 styling.

Usage:
  1. pac pages download --path ./site --websiteId <id> --modelVersion 2
  2. python3 setup_site.py <path-to-downloaded-site-folder>
  3. pac pages upload --path ./site
"""

import os
import sys
import uuid
import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "..", "templates")


def read_template(name):
    path = os.path.join(TEMPLATES_DIR, f"{name}.html")
    with open(path, "r") as f:
        return f.read()


def find_site_root(path):
    """Find the actual site root (contains website.yml)."""
    if os.path.exists(os.path.join(path, "website.yml")):
        return path
    for d in os.listdir(path):
        candidate = os.path.join(path, d)
        if os.path.isdir(candidate) and os.path.exists(os.path.join(candidate, "website.yml")):
            return candidate
    return None


def load_yaml(path):
    with open(path, "r") as f:
        return yaml.safe_load(f)


def save_yaml(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, width=10000)


def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def new_guid():
    return str(uuid.uuid4())


# ── GC Styling CSS ──────────────────────────────────────────
GC_CSS = """\
:root {
    --gc-red: #AF3C43;
    --gc-red-dark: #922B31;
    --gc-white: #FFFFFF;
    --gc-gray-light: #F8F8F8;
    --gc-gray: #E1E4E7;
    --gc-gray-dark: #333333;
    --gc-blue: #26374A;
    --gc-blue-light: #335075;
    --gc-green: #1B6C2A;
}
body { font-family: 'Noto Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: var(--gc-gray-dark); }
.gc-flag-bar { background: var(--gc-white); border-bottom: 1px solid var(--gc-gray); padding: 8px 0; }
.gc-flag-bar .gc-sig { display:flex; align-items:center; gap:10px; color:var(--gc-red); font-weight:700; font-size:1.15rem; text-decoration:none; }
.gc-flag-bar .maple-leaf { font-size:1.5rem; }
.navbar-gc { background: var(--gc-blue) !important; border-bottom: 3px solid var(--gc-red); }
.navbar-gc .navbar-brand { color: var(--gc-white) !important; font-weight: 600; }
.navbar-gc .nav-link { color: rgba(255,255,255,0.85) !important; }
.navbar-gc .nav-link:hover, .navbar-gc .nav-link.active { color: var(--gc-white) !important; }
.gc-card { border: 1px solid var(--gc-gray); border-radius: 4px; background: var(--gc-white); }
.gc-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
.gc-card .card-header { background: var(--gc-blue); color: var(--gc-white); font-weight: 600; }
.btn-gc-primary { background: var(--gc-blue); color: var(--gc-white); border: none; }
.btn-gc-primary:hover { background: var(--gc-blue-light); color: var(--gc-white); }
.btn-gc-danger { background: var(--gc-red); color: var(--gc-white); border: none; }
.btn-gc-danger:hover { background: var(--gc-red-dark); color: var(--gc-white); }
.btn-gc-success { background: var(--gc-green); color: var(--gc-white); border: none; }
.btn-gc-success:hover { background: #155722; color: var(--gc-white); }
.table-gc thead { background: var(--gc-blue); color: var(--gc-white); }
.table-gc thead th { font-weight: 600; border: none; }
.badge-draft { background: #6c757d; }
.badge-ready { background: var(--gc-blue); }
.badge-sent { background: #0d6efd; }
.badge-signed { background: var(--gc-green); }
.badge-cancelled { background: var(--gc-red); }
.gc-footer { background: var(--gc-blue); color: rgba(255,255,255,0.7); padding: 2rem 0; }
.gc-footer a { color: rgba(255,255,255,0.85); text-decoration: none; }
.gc-footer a:hover { color: var(--gc-white); }
.gc-footer-bar { background: var(--gc-gray-dark); padding: 10px 0; text-align: center; }
.gc-footer-bar .gc-wordmark { color: var(--gc-white); font-weight: 700; font-size: 1rem; }
#pdf-viewer { background: #525659; border-radius: 0 0 4px 4px; min-height: 600px; }
#pdf-viewer canvas { display: block; margin: 0 auto; max-width: 100%; }
.pdf-toolbar { background: var(--gc-blue); color: white; padding: 8px 16px; border-radius: 4px 4px 0 0; display: flex; align-items: center; gap: 12px; }
.pdf-toolbar .btn { color: white; }
"""

# ── Header HTML ─────────────────────────────────────────────
GC_HEADER = """\
<!-- GC Flag Bar -->
<div class="gc-flag-bar">
    <div class="container">
        <a href="/" class="gc-sig">
            <span class="maple-leaf">&#127809;</span>
            <span>Government of Canada / Gouvernement du Canada</span>
        </a>
    </div>
</div>
<!-- GC Navigation -->
<div class="navbar navbar-expand-lg navbar-gc" role="banner">
    <div class="container">
        <a class="navbar-brand" href="/"><i class="bi bi-pen-fill me-2"></i>Nintex eSign Portal</a>
        <button class="navbar-toggler border-light" type="button" data-bs-toggle="collapse" data-bs-target="#mainNav">
            <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="mainNav">
            <ul class="nav navbar-nav ms-auto">
                <li class="nav-item"><a class="nav-link" href="/"><i class="bi bi-house-door me-1"></i>Home</a></li>
                <li class="nav-item"><a class="nav-link" href="/envelopes/"><i class="bi bi-envelope me-1"></i>Envelopes</a></li>
                <li class="nav-item"><a class="nav-link" href="/templates/"><i class="bi bi-file-earmark-text me-1"></i>Templates</a></li>
                <li class="nav-item"><a class="nav-link" href="/document-viewer/"><i class="bi bi-eye me-1"></i>Viewer</a></li>
                {% if user %}
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#" data-bs-toggle="dropdown"><i class="bi bi-person-circle me-1"></i>{{ user.fullname }}</a>
                    <ul class="dropdown-menu dropdown-menu-end">
                        <li><a class="dropdown-item" href="{{ website.sign_out_url_substitution }}"><i class="bi bi-box-arrow-right me-2"></i>Sign Out</a></li>
                    </ul>
                </li>
                {% else %}
                <li class="nav-item"><a class="nav-link" href="{{ website.sign_in_url_substitution }}"><i class="bi bi-box-arrow-in-right me-1"></i>Sign In</a></li>
                {% endif %}
            </ul>
        </div>
    </div>
</div>
"""

# ── Footer HTML ─────────────────────────────────────────────
GC_FOOTER = """\
<footer class="gc-footer">
    <div class="container">
        <div class="row">
            <div class="col-md-4 mb-3">
                <h6 class="text-white">Nintex eSign Portal</h6>
                <p class="small">Secure electronic signature management for Government of Canada documents.</p>
            </div>
            <div class="col-md-4 mb-3">
                <h6 class="text-white">Quick Links</h6>
                <ul class="list-unstyled small">
                    <li><a href="/envelopes/">Manage Envelopes</a></li>
                    <li><a href="/templates/">Manage Templates</a></li>
                    <li><a href="/document-viewer/">Document Viewer</a></li>
                </ul>
            </div>
            <div class="col-md-4 mb-3">
                <h6 class="text-white">Support</h6>
                <ul class="list-unstyled small">
                    <li><a href="#">Help &amp; Documentation</a></li>
                    <li><a href="#">Contact Administrator</a></li>
                </ul>
            </div>
        </div>
    </div>
</footer>
<div class="gc-footer-bar">
    <span class="gc-wordmark">&#127809; Canada</span>
</div>
"""


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 setup_site.py <downloaded-site-path>")
        print("  e.g. python3 setup_site.py ./site")
        sys.exit(1)

    site_path = sys.argv[1]
    site_root = find_site_root(site_path)
    if not site_root:
        print(f"Error: Could not find website.yml in {site_path}")
        sys.exit(1)

    print(f"Site root: {site_root}")
    website = load_yaml(os.path.join(site_root, "website.yml"))
    website_id = website["adx_websiteid"]
    print(f"Website ID: {website_id}")

    # Get publishing state ID from existing home page
    home_yml = os.path.join(site_root, "web-pages", "home", "Home.webpage.yml")
    home_data = load_yaml(home_yml)
    pub_state_id = home_data.get("adx_publishingstateid", "")
    home_page_id = home_data["adx_webpageid"]
    page_template_id = home_data["adx_pagetemplateid"]
    lang_yml = os.path.join(site_root, "web-pages", "home", "content-pages", "Home.en-US.webpage.yml")
    lang_data = load_yaml(lang_yml)
    language_id = lang_data.get("adx_webpagelanguageid", "")

    print(f"Publishing state: {pub_state_id}")
    print(f"Home page: {home_page_id}")
    print(f"Page template: {page_template_id}")
    print(f"Language: {language_id}")
    print()

    # ── 1. Update Header ──
    print("Updating Header web template...")
    header_source = os.path.join(site_root, "web-templates", "header", "Header.webtemplate.source.html")
    write_file(header_source, GC_HEADER)

    # ── 2. Update Footer ──
    print("Updating Footer web template...")
    footer_source = os.path.join(site_root, "web-templates", "footer", "Footer.webtemplate.source.html")
    write_file(footer_source, GC_FOOTER)

    # ── 3. Create web templates for new pages ──
    new_templates = {}
    for name in ["Envelopes", "Templates", "DocumentViewer"]:
        print(f"Creating web template: {name}...")
        tpl_dir = os.path.join(site_root, "web-templates", name.lower())
        tpl_id = new_guid()
        new_templates[name] = tpl_id

        save_yaml(os.path.join(tpl_dir, f"{name}.webtemplate.yml"), {
            "adx_name": name,
            "adx_webtemplateid": tpl_id,
        })
        write_file(os.path.join(tpl_dir, f"{name}.webtemplate.source.html"),
                    read_template(name))

    # ── 4. Create page templates for new pages ──
    new_page_templates = {}
    for name in ["Envelopes", "Templates", "DocumentViewer"]:
        print(f"Creating page template: {name}...")
        pt_id = new_guid()
        new_page_templates[name] = pt_id

        save_yaml(os.path.join(site_root, "page-templates", f"{name}.pagetemplate.yml"), {
            "adx_description": f"{name} page",
            "adx_entityname": "adx_webpage",
            "adx_isdefault": False,
            "adx_name": name,
            "adx_pagetemplateid": pt_id,
            "adx_type": 756150001,
            "adx_usewebsiteheaderandfooter": True,
            "adx_webtemplateid": new_templates[name],
        })

    # ── 5. Create web pages ──
    pages = [
        ("Envelopes", "/envelopes", 2),
        ("Templates", "/templates", 3),
        ("Document-Viewer", "/document-viewer", 4),
    ]

    for page_name, partial_url, display_order in pages:
        clean_name = page_name.replace("-", " ").title().replace(" ", "-")
        template_key = page_name.replace("-", "")
        if template_key == "DocumentViewer":
            pass
        elif template_key == "Document-Viewer":
            template_key = "DocumentViewer"

        template_key = page_name.replace("-", "")
        # Map folder name to template key
        tpl_key_map = {
            "Envelopes": "Envelopes",
            "Templates": "Templates",
            "Document-Viewer": "DocumentViewer",
        }
        tpl_key = tpl_key_map[page_name]

        print(f"Creating web page: {page_name} ({partial_url})...")
        page_dir = os.path.join(site_root, "web-pages", page_name.lower())
        content_dir = os.path.join(page_dir, "content-pages")
        os.makedirs(content_dir, exist_ok=True)

        root_page_id = new_guid()
        content_page_id = new_guid()
        pt_id = new_page_templates[tpl_key]

        # Root page
        save_yaml(os.path.join(page_dir, f"{page_name}.webpage.yml"), {
            "adx_displayorder": display_order,
            "adx_enablerating": False,
            "adx_enabletracking": False,
            "adx_excludefromsearch": False,
            "adx_feedbackpolicy": 756150005,
            "adx_hiddenfromsitemap": False,
            "adx_isroot": True,
            "adx_name": page_name.replace("-", " "),
            "adx_pagetemplateid": pt_id,
            "adx_parentpageid": home_page_id,
            "adx_partialurl": partial_url,
            "adx_publishingstateid": pub_state_id,
            "adx_sharedpageconfiguration": False,
            "adx_title": page_name.replace("-", " "),
            "adx_webpageid": root_page_id,
        })
        write_file(os.path.join(page_dir, f"{page_name}.webpage.copy.html"), "")
        write_file(os.path.join(page_dir, f"{page_name}.webpage.custom_css.css"), "")
        write_file(os.path.join(page_dir, f"{page_name}.webpage.custom_javascript.js"), "")
        write_file(os.path.join(page_dir, f"{page_name}.webpage.summary.html"), "")

        # Content page (en-US)
        save_yaml(os.path.join(content_dir, f"{page_name}.en-US.webpage.yml"), {
            "adx_displayorder": display_order,
            "adx_enablerating": False,
            "adx_enabletracking": False,
            "adx_excludefromsearch": False,
            "adx_feedbackpolicy": 756150005,
            "adx_hiddenfromsitemap": False,
            "adx_isroot": False,
            "adx_name": page_name.replace("-", " "),
            "adx_pagetemplateid": pt_id,
            "adx_partialurl": partial_url,
            "adx_publishingstateid": pub_state_id,
            "adx_rootwebpageid": root_page_id,
            "adx_sharedpageconfiguration": False,
            "adx_title": page_name.replace("-", " "),
            "adx_webpageid": content_page_id,
            "adx_webpagelanguageid": language_id,
        })
        write_file(os.path.join(content_dir, f"{page_name}.en-US.webpage.copy.html"), "")
        write_file(os.path.join(content_dir, f"{page_name}.en-US.webpage.custom_css.css"), "")
        write_file(os.path.join(content_dir, f"{page_name}.en-US.webpage.custom_javascript.js"), "")
        write_file(os.path.join(content_dir, f"{page_name}.en-US.webpage.summary.html"), "")

    # ── 6. Update Home page with dashboard HTML ──
    print("Updating Home page content...")
    home_copy = os.path.join(site_root, "web-pages", "home", "content-pages", "Home.en-US.webpage.copy.html")
    write_file(home_copy, read_template("Home"))

    # ── 7. Add GC CSS to Home page (applies globally via header) ──
    print("Adding GC CSS...")
    # Add CSS as a content snippet that gets included in the header
    snippets_dir = os.path.join(site_root, "content-snippets")
    os.makedirs(snippets_dir, exist_ok=True)

    # ── 8. Update site settings ──
    print("Updating site settings for Web API access...")
    settings_file = os.path.join(site_root, "sitesetting.yml")
    settings = load_yaml(settings_file) if os.path.exists(settings_file) else []
    if not isinstance(settings, list):
        settings = [settings] if settings else []

    existing_names = {s.get("adx_name", "") for s in settings if isinstance(s, dict)}

    new_settings = {
        "Webapi/cs_envelopes/enabled": "true",
        "Webapi/cs_envelopes/fields": "*",
        "Webapi/cs_signers/enabled": "true",
        "Webapi/cs_signers/fields": "*",
        "Webapi/cs_documents/enabled": "true",
        "Webapi/cs_documents/fields": "*",
        "Webapi/cs_templates/enabled": "true",
        "Webapi/cs_templates/fields": "*",
        "Webapi/error/innererror": "true",
        "HTTP/X-Frame-Options": "ALLOWALL",
    }

    for name, value in new_settings.items():
        if name not in existing_names:
            settings.append({
                "adx_sitesettingid": new_guid(),
                "adx_name": name,
                "adx_value": value,
            })

    save_yaml(settings_file, settings)

    # ── 9. Add Bootstrap Icons CDN to head via content snippet ──
    # Update the default studio template to include our CSS + CDN links
    print("Updating default template with CDN links and GC CSS...")
    default_tpl_dir = os.path.join(site_root, "web-templates", "default-studio-template")
    default_tpl_source = os.path.join(default_tpl_dir, "Default-studio-template.webtemplate.source.html")

    # Read existing source
    existing_source = ""
    if os.path.exists(default_tpl_source):
        with open(default_tpl_source, "r") as f:
            existing_source = f.read()

    # Inject CDN links and GC CSS at the top
    cdn_block = """\
<!-- Bootstrap Icons CDN -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet"/>
<!-- PDF.js for document viewing -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<!-- GC Custom Styles -->
<style>
""" + GC_CSS + """\
</style>
"""

    if "bootstrap-icons" not in existing_source:
        write_file(default_tpl_source, cdn_block + "\n" + existing_source)

    print()
    print("=" * 55)
    print("  Setup complete!")
    print("=" * 55)
    print()
    print("Next steps:")
    print(f"  1. Upload:  pac pages upload --path {os.path.dirname(site_root)}")
    print("  2. Go to make.powerpages.microsoft.com")
    print("  3. Configure Table Permissions:")
    print("     - Envelopes (cs_envelopes): Read, Write, Create")
    print("     - Signers (cs_signers): Read, Write, Create")
    print("     - Documents (cs_documents): Read, Write, Create")
    print("     - Templates (cs_templates): Read, Write, Create")
    print("  4. Add pages to the site navigation (Web Link Set)")
    print("  5. Enable authentication if not already enabled")
    print()


if __name__ == "__main__":
    main()
