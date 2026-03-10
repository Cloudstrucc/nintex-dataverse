#!/usr/bin/env python3
"""
Setup script for Nintex eSign Power Pages site.

Usage:
  1. Create a blank Power Pages site in make.powerpages.microsoft.com
  2. Download it:  pac pages download --path ./site --websiteId <id>
  3. Run this script: python3 setup_site.py ./site
  4. Upload:  pac pages upload --path ./site

This script updates the downloaded site with:
- GC-styled Bootstrap 5 layout template
- Home, Envelopes, Templates, and Document Viewer pages
- Site settings for table permissions and Web API access
"""

import os
import sys
import yaml
import uuid
import glob
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "..", "templates")


def read_template(name):
    """Read an HTML template file."""
    path = os.path.join(TEMPLATES_DIR, f"{name}.html")
    with open(path, "r") as f:
        return f.read()


def find_yaml_files(site_dir, pattern):
    """Find YAML files matching a pattern in the site directory."""
    results = []
    for root, dirs, files in os.walk(site_dir):
        for f in files:
            if f.endswith(pattern):
                results.append(os.path.join(root, f))
    return results


def get_website_id(site_dir):
    """Extract the website ID from the downloaded site."""
    website_file = os.path.join(site_dir, "website.yml")
    if not os.path.exists(website_file):
        # Try to find it
        candidates = find_yaml_files(site_dir, "website.yml")
        if candidates:
            website_file = candidates[0]
        else:
            return None

    with open(website_file, "r") as f:
        data = yaml.safe_load(f)
    return data.get("adx_websiteid")


def create_web_template(site_dir, name, source, website_id):
    """Create or update a web template YAML file."""
    templates_dir = os.path.join(site_dir, "web-templates")
    os.makedirs(templates_dir, exist_ok=True)

    # Check if template already exists
    existing = find_yaml_files(templates_dir, f"{name}.webtemplate.yml")
    if existing:
        filepath = existing[0]
        with open(filepath, "r") as f:
            data = yaml.safe_load(f)
        data["adx_source"] = source
        template_id = data.get("adx_webtemplateid", str(uuid.uuid4()))
    else:
        filepath = os.path.join(templates_dir, f"{name}.webtemplate.yml")
        template_id = str(uuid.uuid4())
        data = {
            "adx_webtemplateid": template_id,
            "adx_name": name,
            "adx_websiteid": website_id,
            "adx_source": source,
        }

    with open(filepath, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, width=10000)

    print(f"  Web Template: {name} -> {os.path.basename(filepath)}")
    return template_id


def create_page_template(site_dir, name, web_template_id, website_id):
    """Create a page template that links to a web template."""
    pt_dir = os.path.join(site_dir, "page-templates")
    os.makedirs(pt_dir, exist_ok=True)

    # Check existing
    existing = find_yaml_files(pt_dir, f"{name}.pagetemplate.yml")
    if existing:
        filepath = existing[0]
        with open(filepath, "r") as f:
            data = yaml.safe_load(f)
        pt_id = data.get("adx_pagetemplateid", str(uuid.uuid4()))
    else:
        filepath = os.path.join(pt_dir, f"{name}.pagetemplate.yml")
        pt_id = str(uuid.uuid4())
        data = {
            "adx_pagetemplateid": pt_id,
            "adx_name": name,
            "adx_websiteid": website_id,
            "adx_webtemplateid": web_template_id,
            "adx_usewebsiteheaderandfooter": True,
            "adx_type": 756150001,  # Web Template type
        }

    with open(filepath, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

    print(f"  Page Template: {name} -> {os.path.basename(filepath)}")
    return pt_id


def create_web_page(site_dir, name, partial_url, page_template_id, website_id,
                    parent_page_id=None, display_order=None):
    """Create a web page."""
    pages_dir = os.path.join(site_dir, "web-pages", name.lower().replace(" ", "-"))
    os.makedirs(pages_dir, exist_ok=True)

    # Root page
    page_file = os.path.join(pages_dir, f"{name}.en-US.webpage.yml")

    existing = find_yaml_files(pages_dir, ".webpage.yml")
    root_existing = [f for f in existing if ".webpage.copy.yml" not in f]

    if root_existing:
        page_file = root_existing[0]
        with open(page_file, "r") as f:
            data = yaml.safe_load(f)
        page_id = data.get("adx_webpageid", str(uuid.uuid4()))
    else:
        page_id = str(uuid.uuid4())
        data = {
            "adx_webpageid": page_id,
            "adx_name": name,
            "adx_partialurl": partial_url,
            "adx_websiteid": website_id,
            "adx_pagetemplateid": page_template_id,
            "adx_hiddenfromsitemap": False,
        }

    if parent_page_id:
        data["adx_parentpageid"] = parent_page_id
    if display_order is not None:
        data["adx_displayorder"] = display_order

    with open(page_file, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

    # Content page (copy)
    copy_file = os.path.join(pages_dir, "content-pages",
                             f"{name}.en-US.webpage.copy.yml")
    os.makedirs(os.path.dirname(copy_file), exist_ok=True)

    copy_existing = [f for f in existing if ".webpage.copy.yml" in f]
    if copy_existing:
        copy_file = copy_existing[0]
        with open(copy_file, "r") as f:
            copy_data = yaml.safe_load(f)
    else:
        copy_data = {
            "adx_webpageid": str(uuid.uuid4()),
            "adx_name": name,
            "adx_partialurl": partial_url,
            "adx_websiteid": website_id,
            "adx_rootwebpageid": page_id,
            "adx_pagetemplateid": page_template_id,
        }

    with open(copy_file, "w") as f:
        yaml.dump(copy_data, f, default_flow_style=False, allow_unicode=True)

    print(f"  Web Page: {name} ({partial_url}) -> {os.path.basename(pages_dir)}/")
    return page_id


def create_site_settings(site_dir, website_id):
    """Create site settings for Web API access and table permissions."""
    settings_dir = os.path.join(site_dir, "site-settings")
    os.makedirs(settings_dir, exist_ok=True)

    settings = {
        "Webapi/cs_envelopes/enabled": "true",
        "Webapi/cs_envelopes/fields": "*",
        "Webapi/cs_signers/enabled": "true",
        "Webapi/cs_signers/fields": "*",
        "Webapi/cs_documents/enabled": "true",
        "Webapi/cs_documents/fields": "*",
        "Webapi/cs_templates/enabled": "true",
        "Webapi/cs_templates/fields": "*",
        "Webapi/cs_accesslinks/enabled": "true",
        "Webapi/cs_accesslinks/fields": "*",
        "Webapi/cs_envelopehistories/enabled": "true",
        "Webapi/cs_envelopehistories/fields": "*",
        "Webapi/error/innererror": "true",
    }

    for name, value in settings.items():
        safe_name = name.replace("/", "_").replace("*", "all")
        filepath = os.path.join(settings_dir, f"{safe_name}.sitesetting.yml")

        data = {
            "adx_sitesettingid": str(uuid.uuid4()),
            "adx_name": name,
            "adx_value": value,
            "adx_websiteid": website_id,
        }

        with open(filepath, "w") as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

    print(f"  Site Settings: {len(settings)} settings created")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 setup_site.py <downloaded-site-path>")
        print()
        print("Steps:")
        print("  1. Create a blank site at make.powerpages.microsoft.com")
        print("  2. pac pages download --path ./site --websiteId <id>")
        print("  3. python3 setup_site.py ./site")
        print("  4. pac pages upload --path ./site")
        sys.exit(1)

    site_dir = sys.argv[1]
    if not os.path.isdir(site_dir):
        print(f"Error: {site_dir} is not a directory")
        sys.exit(1)

    print(f"Setting up Nintex eSign Power Pages site in: {site_dir}")
    print()

    # Get website ID
    website_id = get_website_id(site_dir)
    if not website_id:
        print("Warning: Could not find website.yml - using placeholder ID")
        website_id = str(uuid.uuid4())
    else:
        print(f"Website ID: {website_id}")

    print()
    print("Creating web templates...")
    layout_id = create_web_template(site_dir, "Layout", read_template("Layout"), website_id)
    home_id = create_web_template(site_dir, "Home", read_template("Home"), website_id)
    env_id = create_web_template(site_dir, "Envelopes", read_template("Envelopes"), website_id)
    tpl_id = create_web_template(site_dir, "Templates", read_template("Templates"), website_id)
    viewer_id = create_web_template(site_dir, "DocumentViewer", read_template("DocumentViewer"), website_id)

    print()
    print("Creating page templates...")
    home_pt = create_page_template(site_dir, "Home", home_id, website_id)
    env_pt = create_page_template(site_dir, "Envelopes", env_id, website_id)
    tpl_pt = create_page_template(site_dir, "Templates", tpl_id, website_id)
    viewer_pt = create_page_template(site_dir, "DocumentViewer", viewer_id, website_id)

    print()
    print("Creating web pages...")
    home_page = create_web_page(site_dir, "Home", "/", home_pt, website_id,
                                display_order=1)
    create_web_page(site_dir, "Envelopes", "/envelopes", env_pt, website_id,
                    parent_page_id=home_page, display_order=2)
    create_web_page(site_dir, "Templates", "/templates", tpl_pt, website_id,
                    parent_page_id=home_page, display_order=3)
    create_web_page(site_dir, "Document Viewer", "/document-viewer", viewer_pt, website_id,
                    parent_page_id=home_page, display_order=4)

    print()
    print("Creating site settings (Web API access)...")
    create_site_settings(site_dir, website_id)

    print()
    print("=" * 50)
    print("Setup complete!")
    print()
    print("Next steps:")
    print(f"  1. Review the files in {site_dir}")
    print(f"  2. Upload: pac pages upload --path {site_dir}")
    print("  3. Configure table permissions in the Power Pages maker portal")
    print("     (Envelopes, Signers, Documents, Templates - Read/Write/Create)")
    print("  4. Enable authentication in the Power Pages admin center")
    print()


if __name__ == "__main__":
    main()
