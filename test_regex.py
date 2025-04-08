#!/usr/bin/env python3
import re

# mkv regex test
sample_html = """
<tr><td class="n"><a href="2025-03-18_12-14-55.mkv">2025-03-18_12-14-55.mkv</a></td><td class="m">2025-Mar-18 12:29:53</td><td class="s">46.5M</td><td class="t">video/x-matroska</td></tr>
<tr><td class="n"><a href="2025-03-18_12-29-53.mkv">2025-03-18_12-29-53.mkv</a></td><td class="m">2025-Mar-18 12:34:57</td><td class="s">15.9M</td><td class="t">video/x-matroska</td></tr>
"""

# Kayıtları bulmak için regex test
recording_regex = re.compile(r'href="([^"]+\.mkv)"')
matches = recording_regex.findall(sample_html)
print("Bulunan mkv dosyaları:")
for match in matches:
    print(f"- {match}")

# Tarih klasörü bulmak için regex test
date_html = """
<tr class="d"><td class="n"><a href="2025_03_18/">2025_03_18</a>/</td><td class="m">2025-Mar-18 23:50:47</td><td class="s">- &nbsp;</td><td class="t">Directory</td></tr>
<tr class="d"><td class="n"><a href="2025_03_19/">2025_03_19</a>/</td><td class="m">2025-Mar-19 11:39:58</td><td class="s">- &nbsp;</td><td class="t">Directory</td></tr>
"""

date_regex = re.compile(r'href="(\d{4}_\d{2}_\d{2})/')
date_matches = date_regex.findall(date_html)
print("\nBulunan tarih klasörleri:")
for match in date_matches:
    print(f"- {match}")

# Dart'ta kullanılan güncel regex'ler:
print("\nDart'ta kullanılan güncel regex'ler:")
print("Tarih regex: r'href=\"(\\d{4}_\\d{2}_\\d{2})/\"'")
print("Kayıt regex: r'href=\"([^\"]+\\.mkv)\"'")
