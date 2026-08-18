#!/usr/bin/env bash
set -o pipefail

CONFIG="${SENTINEL_CONFIG:-/tests/config.json}"
TEST_PATCH="${SENTINEL_TEST_PATCH:-/tests/tests.patch}"
LOG_DIR="${SENTINEL_LOG_DIR:-/logs/verifier}"
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
STATE_DIR="$LOG_DIR/.sentinel-state"
RESULTS="$STATE_DIR/results.tsv"
F2P_REL="specta-tags/tests/sentinel_transform_contract.rs"
P2P_REL="specta/src/datatype/named.rs"
P2P_SHA="79f18eebbf80e73c38af003b1b0fee5caced2c805eb20ec4d77681bf6f10de85"
P2P_SNAPSHOT_B64="dXNlIHN0ZDo6e2JvcnJvdzo6Q293LCBwYW5pYzo6TG9jYXRpb24sIHN5bmM6OkFyY307Cgp1c2UgY3JhdGU6OnsKICAgIFR5cGVzLAogICAgZGF0YXR5cGU6OnsKICAgICAgICBEYXRhVHlwZSwgTmFtZWRSZWZlcmVuY2UsIFJlZmVyZW5jZSwKICAgICAgICByZWZlcmVuY2U6OntzZWxmLCBHZW5lcmljUmVmZXJlbmNlLCBOYW1lZElkfSwKICAgIH0sCn07CgovLy8gTmFtZWQgdHlwZSByZXByZXNlbnRzIGFueSB0eXBlIHdpdGggaXQncyBvd24gdW5pcXVlIG5hbWUgYW5kIGlkZW50aXR5LgovLy8KLy8vIFRoZXNlIGNhbiBiZWNvbWUgYGV4cG9ydCBNeU5hbWVkVHlwZSA9IC4uLmAgaW4gVHlwZXNjcmlwdCBjYW4gd2UgYmUgcmVmZXJlbmNlZCBpbiB0eXBlcyBsaWtlIGB7IGZpZWxkOiBNeU5hbWVkVHlwZSB9YC4KI1tkZXJpdmUoRGVidWcsIENsb25lLCBQYXJ0aWFsRXEsIEVxKV0KcHViIHN0cnVjdCBOYW1lZERhdGFUeXBlIHsKICAgIHB1YihjcmF0ZSkgaWQ6IE5hbWVkSWQsCiAgICBwdWIoY3JhdGUpIG5hbWU6IENvdzwnc3RhdGljLCBzdHI+LAogICAgcHViKGNyYXRlKSBkb2NzOiBDb3c8J3N0YXRpYywgc3RyPiwKICAgIHB1YihjcmF0ZSkgZGVwcmVjYXRlZDogT3B0aW9uPERlcHJlY2F0ZWQ+LAogICAgcHViKGNyYXRlKSBtb2R1bGVfcGF0aDogQ293PCdzdGF0aWMsIHN0cj4sCiAgICBwdWIoY3JhdGUpIGxvY2F0aW9uOiBMb2NhdGlvbjwnc3RhdGljPiwKICAgIHB1YihjcmF0ZSkgZ2VuZXJpY3M6IENvdzwnc3RhdGljLCBbKEdlbmVyaWNSZWZlcmVuY2UsIENvdzwnc3RhdGljLCBzdHI+KV0+LAogICAgcHViKGNyYXRlKSBpbmxpbmU6IGJvb2wsCiAgICBwdWIoY3JhdGUpIGlubmVyOiBEYXRhVHlwZSwKfQoKaW1wbCBOYW1lZERhdGFUeXBlIHsKICAgIC8vLyBDb25zdHJ1Y3QgYSBuZXcgbmFtZWQgZGF0YXR5cGUuCiAgICAvLy8KICAgIC8vLyBOb3RlOiBFbnN1cmUgeW91IGNhbGwgYFNlbGY6OnJlZ2lzdGVyYCB0byByZWdpc3RlciB0aGUgdHlwZS4KICAgICNbdHJhY2tfY2FsbGVyXQogICAgcHViIGZuIG5ldygKICAgICAgICBuYW1lOiBpbXBsIEludG88Q293PCdzdGF0aWMsIHN0cj4+LAogICAgICAgIGdlbmVyaWNzOiBWZWM8KEdlbmVyaWNSZWZlcmVuY2UsIENvdzwnc3RhdGljLCBzdHI+KT4sCiAgICAgICAgZHQ6IERhdGFUeXBlLAogICAgKSAtPiBTZWxmIHsKICAgICAgICBsZXQgbG9jYXRpb24gPSBMb2NhdGlvbjo6Y2FsbGVyKCk7CiAgICAgICAgU2VsZiB7CiAgICAgICAgICAgIGlkOiBOYW1lZElkOjpEeW5hbWljKEFyYzo6bmV3KCgpKSksCiAgICAgICAgICAgIG5hbWU6IG5hbWUuaW50bygpLAogICAgICAgICAgICBkb2NzOiBDb3c6OkJvcnJvd2VkKCIiKSwKICAgICAgICAgICAgZGVwcmVjYXRlZDogTm9uZSwKICAgICAgICAgICAgbW9kdWxlX3BhdGg6IGZpbGVfcGF0aF90b19tb2R1bGVfcGF0aChsb2NhdGlvbi5maWxlKCkpCiAgICAgICAgICAgICAgICAubWFwKEludG86OmludG8pCiAgICAgICAgICAgICAgICAudW53cmFwX29yKENvdzo6Qm9ycm93ZWQoInZpcnR1YWwiKSksCiAgICAgICAgICAgIGxvY2F0aW9uOiBsb2NhdGlvbi50b19vd25lZCgpLAogICAgICAgICAgICBnZW5lcmljczogQ293OjpPd25lZChnZW5lcmljcyksCiAgICAgICAgICAgIGlubGluZTogZmFsc2UsCiAgICAgICAgICAgIGlubmVyOiBkdCwKICAgICAgICB9CiAgICB9CgogICAgLy8vIENvbnN0cnVjdCBhIG5ldyBpbmxpbmVkIG5hbWVkIGRhdGF0eXBlLgogICAgLy8vCiAgICAvLy8gTm90ZTogRW5zdXJlIHlvdSBjYWxsIGBTZWxmOjpyZWdpc3RlcmAgdG8gcmVnaXN0ZXIgdGhlIHR5cGUuCiAgICAjW3RyYWNrX2NhbGxlcl0KICAgIHB1YiBmbiBuZXdfaW5saW5lKAogICAgICAgIG5hbWU6IGltcGwgSW50bzxDb3c8J3N0YXRpYywgc3RyPj4sCiAgICAgICAgZ2VuZXJpY3M6IFZlYzwoR2VuZXJpY1JlZmVyZW5jZSwgQ293PCdzdGF0aWMsIHN0cj4pPiwKICAgICAgICBkdDogRGF0YVR5cGUsCiAgICApIC0+IFNlbGYgewogICAgICAgIGxldCBsb2NhdGlvbiA9IExvY2F0aW9uOjpjYWxsZXIoKTsKICAgICAgICBTZWxmIHsKICAgICAgICAgICAgaWQ6IE5hbWVkSWQ6OkR5bmFtaWMoQXJjOjpuZXcoKCkpKSwKICAgICAgICAgICAgbmFtZTogbmFtZS5pbnRvKCksCiAgICAgICAgICAgIGRvY3M6IENvdzo6Qm9ycm93ZWQoIiIpLAogICAgICAgICAgICBkZXByZWNhdGVkOiBOb25lLAogICAgICAgICAgICBtb2R1bGVfcGF0aDogZmlsZV9wYXRoX3RvX21vZHVsZV9wYXRoKGxvY2F0aW9uLmZpbGUoKSkKICAgICAgICAgICAgICAgIC5tYXAoSW50bzo6aW50bykKICAgICAgICAgICAgICAgIC51bndyYXBfb3IoQ293OjpCb3Jyb3dlZCgidmlydHVhbCIpKSwKICAgICAgICAgICAgbG9jYXRpb246IGxvY2F0aW9uLnRvX293bmVkKCksCiAgICAgICAgICAgIGdlbmVyaWNzOiBDb3c6Ok93bmVkKGdlbmVyaWNzKSwKICAgICAgICAgICAgaW5saW5lOiB0cnVlLAogICAgICAgICAgICBpbm5lcjogZHQsCiAgICAgICAgfQogICAgfQoKICAgIC8vLyBSZWdpc3RlciB0aGUgdHlwZSBpbnRvIGEgW1R5cGVzXS4KICAgIHB1YiBmbiByZWdpc3Rlcigmc2VsZiwgdHlwZXM6ICZtdXQgVHlwZXMpIHsKICAgICAgICB0eXBlcy4wLmluc2VydChzZWxmLmlkLmNsb25lKCksIFNvbWUoc2VsZi5jbG9uZSgpKSk7CiAgICAgICAgdHlwZXMuMSArPSAxOwogICAgfQoKICAgIC8vICMjIFdoeSByZXR1cm4gYSByZWZlcmVuY2U/CiAgICAvLwogICAgLy8gSWYgYSByZWN1cnNpdmUgdHlwZSBpcyBiZWluZyByZXNvbHZlZCBpdCdzIHBvc3NpYmxlIHRoZSBgaW5pdF93aXRoX3NlbnRpbmVsYCBmdW5jdGlvbiB3aWxsIGJlIGNhbGxlZCByZWN1cnNpdmVseS4KICAgIC8vIFRvIGF2b2lkIHRoaXMgd2UgYXZvaWQgcmVzb2x2aW5nIGEgdHlwZSB0aGF0J3MgYWxyZWFkeSBtYXJrZWQgYXMgYmVpbmcgcmVzb2x2ZWQgYnV0IHRoaXMgbWVhbnMgdGhlIFtOYW1lZERhdGFUeXBlXSdzIFtEYXRhVHlwZV0gaXMgdW5rbm93biBhdCB0aGlzIHN0YWdlIHNvIHdlIGNhbid0IHJldHVybiBpdC4gSW5zdGVhZCB3ZSBhbHdheXMgcmV0dXJuIFtSZWZlcmVuY2VdJ3MgYXMgdGhleSBhcmUgYWx3YXlzIHZhbGlkLgogICAgLy8gV0FSTklORzogVGhpcyBzaG91bGQgbm90IGJlIHVzZWQgb3V0c2lkZSBvZiBgc3BlY3RhX21hY3Jvc2AgYXMgaXQgbWF5IGhhdmUgYnJlYWtpbmcgY2hhbmdlcyBpbiBtaW5vciByZWxlYXNlcwogICAgI1tkb2MoaGlkZGVuKV0KICAgICNbdHJhY2tfY2FsbGVyXQogICAgcHViIGZuIGluaXRfd2l0aF9zZW50aW5lbCgKICAgICAgICBnZW5lcmljc19mb3JfbmR0OiAmJ3N0YXRpYyBbKEdlbmVyaWNSZWZlcmVuY2UsIENvdzwnc3RhdGljLCBzdHI+KV0sCiAgICAgICAgZ2VuZXJpY3NfZm9yX3JlZjogVmVjPChHZW5lcmljUmVmZXJlbmNlLCBEYXRhVHlwZSk+LAogICAgICAgIG11dCBpbmxpbmU6IGJvb2wsCiAgICAgICAgdHlwZXM6ICZtdXQgVHlwZXMsCiAgICAgICAgc2VudGluZWw6ICYnc3RhdGljIHN0ciwKICAgICAgICBidWlsZF9uZHQ6IGZuKCZtdXQgVHlwZXMsICZtdXQgTmFtZWREYXRhVHlwZSksCiAgICApIC0+IFJlZmVyZW5jZSB7CiAgICAgICAgbGV0IGlkID0gTmFtZWRJZDo6U3RhdGljKHNlbnRpbmVsKTsKICAgICAgICBsZXQgbG9jYXRpb24gPSBMb2NhdGlvbjo6Y2FsbGVyKCkudG9fb3duZWQoKTsKCiAgICAgICAgLy8gV2UgaGF2ZSBuZXZlciBlbmNvdW50ZXJlZCB0aGlzIHR5cGUuIFN0YXJ0IHJlc29sdmluZyBpdCEKICAgICAgICBpZiBsZXQgU29tZShuZHQpID0gdHlwZXMuMC5nZXQoJmlkKSB7CiAgICAgICAgICAgIGlmIGxldCBTb21lKG5kdCkgPSBuZHQgewogICAgICAgICAgICAgICAgaW5saW5lID0gaW5saW5lIHx8IG5kdC5pbmxpbmU7CiAgICAgICAgICAgIH0KICAgICAgICB9IGVsc2UgewogICAgICAgICAgICB0eXBlcy4wLmluc2VydChpZC5jbG9uZSgpLCBOb25lKTsKICAgICAgICAgICAgbGV0IG11dCBuZHQgPSBOYW1lZERhdGFUeXBlIHsKICAgICAgICAgICAgICAgIGlkOiBpZC5jbG9uZSgpLAogICAgICAgICAgICAgICAgbG9jYXRpb24sCiAgICAgICAgICAgICAgICAvLyBgYnVpbGRfbmR0YCB3aWxsIGp1c3Qgb3ZlcnJpZGUgYWxsIG9mIHRoaXMKICAgICAgICAgICAgICAgIG5hbWU6IENvdzo6Qm9ycm93ZWQoIiIpLAogICAgICAgICAgICAgICAgZG9jczogQ293OjpCb3Jyb3dlZCgiIiksCiAgICAgICAgICAgICAgICBkZXByZWNhdGVkOiBOb25lLAogICAgICAgICAgICAgICAgbW9kdWxlX3BhdGg6IENvdzo6Qm9ycm93ZWQoIiIpLAogICAgICAgICAgICAgICAgZ2VuZXJpY3M6IENvdzo6Qm9ycm93ZWQoZ2VuZXJpY3NfZm9yX25kdCksCiAgICAgICAgICAgICAgICBpbmxpbmUsCiAgICAgICAgICAgICAgICBpbm5lcjogRGF0YVR5cGU6OlByaW1pdGl2ZShzdXBlcjo6UHJpbWl0aXZlOjppOCksCiAgICAgICAgICAgIH07CiAgICAgICAgICAgIGJ1aWxkX25kdCh0eXBlcywgJm11dCBuZHQpOwoKICAgICAgICAgICAgLy8gV2UgcGF0Y2ggdGhlIFRhdXJpIGBUeXBlYCBpbXBsZW1lbnRhdGlvbi4KICAgICAgICAgICAgaWYgbmR0Lm5hbWUoKSA9PSAiVEFVUklfQ0hBTk5FTCIgJiYgbmR0Lm1vZHVsZV9wYXRoKCkuc3RhcnRzX3dpdGgoInRhdXJpOjoiKSB7CiAgICAgICAgICAgICAgICAvLyBUaGlzIGNhdXNlcyBhbiBleHBvcnRlciB0aGF0IGlzbid0IGF3YXJlIG9mIFRhdXJpJ3MgY2hhbm5lbCB0byBlcnJvci4KICAgICAgICAgICAgICAgIC8vIFRoaXMgaXMgZWZmZWN0aXZlbHkgYFJlZmVyZW5jZTo6b3BhcXVlKFRhdXJpQ2hhbm5lbClgIGJ1dCB3ZSBkbyBzb21lIGhhY2tlcnkgZm9yIGJldHRlciBlcnJvcnMuCiAgICAgICAgICAgICAgICBuZHQuaW5uZXIgPSByZWZlcmVuY2U6OnRhdXJpKCkuaW50bygpOwoKICAgICAgICAgICAgICAgIC8vIFRoaXMgZW5zdXJlcyB0aGF0IHdlIG5ldmVyIGNyZWF0ZSBhIGBleHBvcnQgdHlwZSBDaGFubmVsYCwKICAgICAgICAgICAgICAgIC8vIGluc3RlYWQgdGhlIGRlZmluaXRpb24gZ2V0cyBpbmxpbmVkIGludG8gZWFjaCBjYWxsc2l0ZS4KICAgICAgICAgICAgICAgIGlubGluZSA9IHRydWU7CiAgICAgICAgICAgICAgICBuZHQuaW5saW5lID0gdHJ1ZTsKICAgICAgICAgICAgfQoKICAgICAgICAgICAgdHlwZXMuMC5pbnNlcnQoaWQuY2xvbmUoKSwgU29tZShuZHQpKTsKICAgICAgICAgICAgdHlwZXMuMSArPSAxOwogICAgICAgIH0KCiAgICAgICAgUmVmZXJlbmNlOjpOYW1lZChOYW1lZFJlZmVyZW5jZSB7CiAgICAgICAgICAgIGlkLAogICAgICAgICAgICBnZW5lcmljczogZ2VuZXJpY3NfZm9yX3JlZiwKICAgICAgICAgICAgaW5saW5lLAogICAgICAgIH0pCiAgICB9CgogICAgLy8vIENvbnN0cnVjdCBhIFtSZWZlcmVuY2VdIHRvIGEgW05hbWVkRGF0YVR5cGVdLgogICAgLy8vIFRoaXMgY2FuIGJlIGluY2x1ZGVkIGluIGEgYERhdGFUeXBlOjpSZWZlcmVuY2VgIHdpdGhpbiBhbm90aGVyIHR5cGUuCiAgICAvLy8KICAgIC8vLyBUaGlzIHJlZmVyZW5jZSB3aWxsIGJlIGlubGluZWQgaWYgdGhlIHR5cGUgaXMgaW5saW5lZCwgb3RoZXJ3aXNlIHlvdSBjYW4gaW5saW5lIGl0IHdpdGggW1JlZmVyZW5jZTo6aW5saW5lXS4KICAgIHB1YiBmbiByZWZlcmVuY2UoJnNlbGYsIGdlbmVyaWNzOiBWZWM8KEdlbmVyaWNSZWZlcmVuY2UsIERhdGFUeXBlKT4pIC0+IFJlZmVyZW5jZSB7CiAgICAgICAgLy8gVE9ETzogYWxsb3cgZ2VuZXJpY3MgdG8gYmUgYENvd2AKICAgICAgICAvLyBUT0RPOiBIYXNoTWFwIGluc3RlYWQgb2YgYXJyYXkgZm9yIGJldHRlciB0eXBlc2FmZXR5Pz8KCiAgICAgICAgUmVmZXJlbmNlOjpOYW1lZChOYW1lZFJlZmVyZW5jZSB7CiAgICAgICAgICAgIGlkOiBzZWxmLmlkLmNsb25lKCksCiAgICAgICAgICAgIGdlbmVyaWNzLAogICAgICAgICAgICBpbmxpbmU6IHNlbGYuaW5saW5lLAogICAgICAgIH0pCiAgICB9CgogICAgLy8vIENoZWNrIHdoZXRoZXIgYSB0eXBlIHJlcXVpcmVzIGEgcmVmZXJlbmNlIHRvIGJlIGdlbmVyYXRlZC4KICAgIC8vLwogICAgLy8vIFRoaXMgaWYgYGZhbHNlYCBpcyBhbGwgW1JlZmVyZW5jZV0ncyBjcmVhdGVkIGZvciB0aGUgdHlwZSBhcmUgaW5saW5lZCwKICAgIC8vLyBpbiB0aGF0IGNhc2UgaXQgZG9lc24ndCBuZWVkIHRvIGJlIGV4cG9ydGVkIGJlY2F1c2UgaXQgd2lsbCBuZXZlciBiZQogICAgLy8vIHJlZmVyZW5jZWQuCiAgICBwdWIgZm4gcmVxdWlyZXNfcmVmZXJlbmNlKCZzZWxmLCBfdHlwZXM6ICZUeXBlcykgLT4gYm9vbCB7CiAgICAgICAgLy8gYFR5cGVzYCBpcyB1bnVzZWQgYnV0IEkgd2FubmEga2VlcCBpdCBmb3IgZnV0dXJlIGZsZXhpYmlsaXR5LgoKICAgICAgICAvLyBJZiBhIHR5cGUgaXMgaW5saW5lZCwgYWxsIGl0J3MgcmVmZXJlbmNlcyBhcmUsCiAgICAgICAgLy8gdGhlcmVmb3Igd2UgZG9uJ3QgbmVlZCB0byBleHBvcnQgYSBuYW1lZCB2ZXJzaW9uIG9mIGl0LgogICAgICAgICFzZWxmLmlubGluZQogICAgfQoKICAgIC8vLyBUaGUgbmFtZSBvZiB0aGUgdHlwZQogICAgcHViIGZuIG5hbWUoJnNlbGYpIC0+ICZDb3c8J3N0YXRpYywgc3RyPiB7CiAgICAgICAgJnNlbGYubmFtZQogICAgfQoKICAgIC8vLyBHZXQgYSBtdXRhYmxlIHJlZmVyZW5jZSB0byB0aGUgbmFtZSBvZiB0aGUgdHlwZQogICAgcHViIGZuIG5hbWVfbXV0KCZtdXQgc2VsZikgLT4gJm11dCBDb3c8J3N0YXRpYywgc3RyPiB7CiAgICAgICAgJm11dCBzZWxmLm5hbWUKICAgIH0KCiAgICAvLy8gU2V0IHRoZSBuYW1lIG9mIHRoZSB0eXBlCiAgICBwdWIgZm4gc2V0X25hbWUoJm11dCBzZWxmLCBuYW1lOiBDb3c8J3N0YXRpYywgc3RyPikgewogICAgICAgIHNlbGYubmFtZSA9IG5hbWU7CiAgICB9CgogICAgLy8vIFJ1c3QgZG9jdW1lbnRhdGlvbiBjb21tZW50cyBvbiB0aGUgdHlwZQogICAgcHViIGZuIGRvY3MoJnNlbGYpIC0+ICZDb3c8J3N0YXRpYywgc3RyPiB7CiAgICAgICAgJnNlbGYuZG9jcwogICAgfQoKICAgIC8vLyBHZXQgYSBtdXRhYmxlIHJlZmVyZW5jZSB0byB0aGUgUnVzdCBkb2N1bWVudGF0aW9uIGNvbW1lbnRzIG9uIHRoZSB0eXBlCiAgICBwdWIgZm4gZG9jc19tdXQoJm11dCBzZWxmKSAtPiAmbXV0IENvdzwnc3RhdGljLCBzdHI+IHsKICAgICAgICAmbXV0IHNlbGYuZG9jcwogICAgfQoKICAgIC8vLyBTZXQgdGhlIFJ1c3QgZG9jdW1lbnRhdGlvbiBjb21tZW50cyBvbiB0aGUgdHlwZQogICAgcHViIGZuIHNldF9kb2NzKCZtdXQgc2VsZiwgZG9jczogQ293PCdzdGF0aWMsIHN0cj4pIHsKICAgICAgICBzZWxmLmRvY3MgPSBkb2NzOwogICAgfQoKICAgIC8vLyBUaGUgUnVzdCBkZXByZWNhdGVkIGNvbW1lbnQgaWYgdGhlIHR5cGUgaXMgZGVwcmVjYXRlZC4KICAgIHB1YiBmbiBkZXByZWNhdGVkKCZzZWxmKSAtPiBPcHRpb248JkRlcHJlY2F0ZWQ+IHsKICAgICAgICBzZWxmLmRlcHJlY2F0ZWQuYXNfcmVmKCkKICAgIH0KCiAgICAvLy8gR2V0IGEgbXV0YWJsZSByZWZlcmVuY2UgdG8gdGhlIFJ1c3QgZGVwcmVjYXRlZCBjb21tZW50IGlmIHRoZSB0eXBlIGlzIGRlcHJlY2F0ZWQuCiAgICBwdWIgZm4gZGVwcmVjYXRlZF9tdXQoJm11dCBzZWxmKSAtPiBPcHRpb248Jm11dCBEZXByZWNhdGVkPiB7CiAgICAgICAgc2VsZi5kZXByZWNhdGVkLmFzX211dCgpCiAgICB9CgogICAgLy8vIFNldCB0aGUgUnVzdCBkZXByZWNhdGVkIGNvbW1lbnQgaWYgdGhlIHR5cGUgaXMgZGVwcmVjYXRlZC4KICAgIHB1YiBmbiBzZXRfZGVwcmVjYXRlZCgmbXV0IHNlbGYsIGRlcHJlY2F0ZWQ6IE9wdGlvbjxEZXByZWNhdGVkPikgewogICAgICAgIHNlbGYuZGVwcmVjYXRlZCA9IGRlcHJlY2F0ZWQ7CiAgICB9CgogICAgLy8vIFRoZSBjb2RlIGxvY2F0aW9uIHdoZXJlIHRoaXMgdHlwZSBpcyBpbXBsZW1lbnRlZAogICAgcHViIGZuIGxvY2F0aW9uKCZzZWxmKSAtPiBMb2NhdGlvbjwnc3RhdGljPiB7CiAgICAgICAgc2VsZi5sb2NhdGlvbgogICAgfQoKICAgIC8vLyBTZXQgdGhlIGNvZGUgbG9jYXRpb24gd2hlcmUgdGhpcyB0eXBlIGlzIGltcGxlbWVudGVkCiAgICBwdWIgZm4gc2V0X2xvY2F0aW9uKCZtdXQgc2VsZiwgbG9jYXRpb246IExvY2F0aW9uPCdzdGF0aWM+KSB7CiAgICAgICAgc2VsZi5sb2NhdGlvbiA9IGxvY2F0aW9uOwogICAgfQoKICAgIC8vLyBUaGUgUnVzdCBwYXRoIG9mIHRoZSBtb2R1bGUgd2hlcmUgdGhpcyB0eXBlIGlzIGRlZmluZWQKICAgIHB1YiBmbiBtb2R1bGVfcGF0aCgmc2VsZikgLT4gJkNvdzwnc3RhdGljLCBzdHI+IHsKICAgICAgICAmc2VsZi5tb2R1bGVfcGF0aAogICAgfQoKICAgIC8vLyBHZXQgYSBtdXRhYmxlIHJlZmVyZW5jZSB0byB0aGUgUnVzdCBwYXRoIG9mIHRoZSBtb2R1bGUgd2hlcmUgdGhpcyB0eXBlIGlzIGRlZmluZWQKICAgIHB1YiBmbiBtb2R1bGVfcGF0aF9tdXQoJm11dCBzZWxmKSAtPiAmbXV0IENvdzwnc3RhdGljLCBzdHI+IHsKICAgICAgICAmbXV0IHNlbGYubW9kdWxlX3BhdGgKICAgIH0KCiAgICAvLy8gU2V0IHRoZSBSdXN0IHBhdGggb2YgdGhlIG1vZHVsZSB3aGVyZSB0aGlzIHR5cGUgaXMgZGVmaW5lZAogICAgcHViIGZuIHNldF9tb2R1bGVfcGF0aCgmbXV0IHNlbGYsIG1vZHVsZV9wYXRoOiBDb3c8J3N0YXRpYywgc3RyPikgewogICAgICAgIHNlbGYubW9kdWxlX3BhdGggPSBtb2R1bGVfcGF0aDsKICAgIH0KCiAgICAvLy8gVGhlIGdlbmVyaWNzIHRoYXQgYXJlIGRlZmluZWQgb24gdGhpcyB0eXBlCiAgICBwdWIgZm4gZ2VuZXJpY3MoJnNlbGYpIC0+ICZbKEdlbmVyaWNSZWZlcmVuY2UsIENvdzwnc3RhdGljLCBzdHI+KV0gewogICAgICAgICZzZWxmLmdlbmVyaWNzCiAgICB9CgogICAgLy8vIEdldCBhIG11dGFibGUgcmVmZXJlbmNlIHRvIHRoZSBnZW5lcmljcyB0aGF0IGFyZSBkZWZpbmVkIG9uIHRoaXMgdHlwZQogICAgcHViIGZuIGdlbmVyaWNzX211dCgmbXV0IHNlbGYpIC0+ICZtdXQgQ293PCdzdGF0aWMsIFsoR2VuZXJpY1JlZmVyZW5jZSwgQ293PCdzdGF0aWMsIHN0cj4pXT4gewogICAgICAgICZtdXQgc2VsZi5nZW5lcmljcwogICAgfQoKICAgIC8vLyBHZXQgdGhlIGlubmVyIFtgRGF0YVR5cGVgXQogICAgcHViIGZuIHR5KCZzZWxmKSAtPiAmRGF0YVR5cGUgewogICAgICAgICZzZWxmLmlubmVyCiAgICB9CgogICAgLy8vIEdldCBhIG11dGFibGUgcmVmZXJlbmNlIHRvIHRoZSBpbm5lciBbYERhdGFUeXBlYF0KICAgIHB1YiBmbiB0eV9tdXQoJm11dCBzZWxmKSAtPiAmbXV0IERhdGFUeXBlIHsKICAgICAgICAmbXV0IHNlbGYuaW5uZXIKICAgIH0KCiAgICAvLy8gU2V0IHRoZSBpbm5lciBbYERhdGFUeXBlYF0KICAgIHB1YiBmbiBzZXRfdHkoJm11dCBzZWxmLCB0eTogRGF0YVR5cGUpIHsKICAgICAgICBzZWxmLmlubmVyID0gdHk7CiAgICB9Cn0KCiNbZGVyaXZlKERlYnVnLCBDbG9uZSwgRGVmYXVsdCwgUGFydGlhbEVxLCBFcSwgSGFzaCldCi8vLyBSdW50aW1lIHJlcHJlc2VudGF0aW9uIG9mIFJ1c3QncyBgI1tkZXByZWNhdGVkXWAgbWV0YWRhdGEuCnB1YiBzdHJ1Y3QgRGVwcmVjYXRlZCB7CiAgICBub3RlOiBPcHRpb248Q293PCdzdGF0aWMsIHN0cj4+LAogICAgc2luY2U6IE9wdGlvbjxDb3c8J3N0YXRpYywgc3RyPj4sCn0KCmltcGwgRGVwcmVjYXRlZCB7CiAgICAvLy8gQ29uc3RydWN0IGRlcHJlY2F0aW9uIG1ldGFkYXRhIHdpdGhvdXQgZGV0YWlscy4KICAgIC8vLwogICAgLy8vIEVnLiBgI1tkZXByZWNhdGVkXWAKICAgIHB1YiBjb25zdCBmbiBuZXcoKSAtPiBTZWxmIHsKICAgICAgICBTZWxmIHsKICAgICAgICAgICAgbm90ZTogTm9uZSwKICAgICAgICAgICAgc2luY2U6IE5vbmUsCiAgICAgICAgfQogICAgfQoKICAgIC8vLyBDb25zdHJ1Y3QgZGVwcmVjYXRpb24gbWV0YWRhdGEgd2l0aCBhIG5vdGUvbWVzc2FnZS4KICAgIC8vLwogICAgLy8vIEVnLiBgI1tkZXByZWNhdGVkID0gIlVzZSBzb21ldGhpbmcgZWxzZSJdYAogICAgcHViIGZuIHdpdGhfbm90ZShub3RlOiBDb3c8J3N0YXRpYywgc3RyPikgLT4gU2VsZiB7CiAgICAgICAgU2VsZiB7CiAgICAgICAgICAgIG5vdGU6IFNvbWUobm90ZSksCiAgICAgICAgICAgIHNpbmNlOiBOb25lLAogICAgICAgIH0KICAgIH0KCiAgICAvLy8gQ29uc3RydWN0IGRlcHJlY2F0aW9uIG1ldGFkYXRhIHdpdGggYSBub3RlL21lc3NhZ2UgYW5kIGFuIG9wdGlvbmFsIGBzaW5jZWAgdmVyc2lvbi4KICAgIC8vLwogICAgLy8vIEVnLiBgI1tkZXByZWNhdGVkKHNpbmNlID0gIjEuMC4wIiwgbm90ZSA9ICJVc2Ugc29tZXRoaW5nIGVsc2UiKV1gCiAgICBwdWIgZm4gd2l0aF9zaW5jZV9ub3RlKHNpbmNlOiBPcHRpb248Q293PCdzdGF0aWMsIHN0cj4+LCBub3RlOiBDb3c8J3N0YXRpYywgc3RyPikgLT4gU2VsZiB7CiAgICAgICAgU2VsZiB7CiAgICAgICAgICAgIG5vdGU6IFNvbWUobm90ZSksCiAgICAgICAgICAgIHNpbmNlLAogICAgICAgIH0KICAgIH0KCiAgICAvLy8gT3B0aW9uYWwgZGVwcmVjYXRpb24gbm90ZS9tZXNzYWdlLgogICAgcHViIGZuIG5vdGUoJnNlbGYpIC0+IE9wdGlvbjwmQ293PCdzdGF0aWMsIHN0cj4+IHsKICAgICAgICBzZWxmLm5vdGUuYXNfcmVmKCkKICAgIH0KCiAgICAvLy8gTXV0YWJsZSBvcHRpb25hbCBkZXByZWNhdGlvbiBub3RlL21lc3NhZ2UuCiAgICBwdWIgZm4gbm90ZV9tdXQoJm11dCBzZWxmKSAtPiBPcHRpb248Jm11dCBDb3c8J3N0YXRpYywgc3RyPj4gewogICAgICAgIHNlbGYubm90ZS5hc19tdXQoKQogICAgfQoKICAgIC8vLyBTZXQgdGhlIG9wdGlvbmFsIGRlcHJlY2F0aW9uIG5vdGUvbWVzc2FnZS4KICAgIHB1YiBmbiBzZXRfbm90ZSgmbXV0IHNlbGYsIG5vdGU6IE9wdGlvbjxDb3c8J3N0YXRpYywgc3RyPj4pIHsKICAgICAgICBzZWxmLm5vdGUgPSBub3RlOwogICAgfQoKICAgIC8vLyBPcHRpb25hbCB2ZXJzaW9uIHN0cmluZyBmcm9tIGBzaW5jZSA9ICIuLi4iYC4KICAgIHB1YiBmbiBzaW5jZSgmc2VsZikgLT4gT3B0aW9uPCZDb3c8J3N0YXRpYywgc3RyPj4gewogICAgICAgIHNlbGYuc2luY2UuYXNfcmVmKCkKICAgIH0KCiAgICAvLy8gTXV0YWJsZSBvcHRpb25hbCB2ZXJzaW9uIHN0cmluZyBmcm9tIGBzaW5jZSA9ICIuLi4iYC4KICAgIHB1YiBmbiBzaW5jZV9tdXQoJm11dCBzZWxmKSAtPiBPcHRpb248Jm11dCBDb3c8J3N0YXRpYywgc3RyPj4gewogICAgICAgIHNlbGYuc2luY2UuYXNfbXV0KCkKICAgIH0KCiAgICAvLy8gU2V0IHRoZSBvcHRpb25hbCB2ZXJzaW9uIHN0cmluZyBmcm9tIGBzaW5jZSA9ICIuLi4iYC4KICAgIHB1YiBmbiBzZXRfc2luY2UoJm11dCBzZWxmLCBzaW5jZTogT3B0aW9uPENvdzwnc3RhdGljLCBzdHI+PikgewogICAgICAgIHNlbGYuc2luY2UgPSBzaW5jZTsKICAgIH0KfQoKZm4gZmlsZV9wYXRoX3RvX21vZHVsZV9wYXRoKGZpbGVfcGF0aDogJnN0cikgLT4gT3B0aW9uPFN0cmluZz4gewogICAgbGV0IG5vcm1hbGl6ZWQgPSBmaWxlX3BhdGgucmVwbGFjZSgnXFwnLCAiLyIpOwoKICAgIC8vIFRyeSBkaWZmZXJlbnQgcHJlZml4ZXMKICAgIGxldCAocHJlZml4LCBwYXRoKSA9IGlmIGxldCBTb21lKHApID0gbm9ybWFsaXplZC5zdHJpcF9wcmVmaXgoInNyYy8iKSB7CiAgICAgICAgKCJjcmF0ZSIsIHApCiAgICB9IGVsc2UgaWYgbGV0IFNvbWUocCkgPSBub3JtYWxpemVkLnN0cmlwX3ByZWZpeCgidGVzdHMvIikgewogICAgICAgICgidGVzdHMiLCBwKQogICAgfSBlbHNlIHsKICAgICAgICByZXR1cm4gTm9uZTsKICAgIH07CgogICAgbGV0IHBhdGggPSBwYXRoLnN0cmlwX3N1ZmZpeCgiLnJzIik/OwogICAgbGV0IHBhdGggPSBwYXRoLnN0cmlwX3N1ZmZpeCgiL21vZCIpLnVud3JhcF9vcihwYXRoKTsKICAgIGxldCBtb2R1bGVfcGF0aCA9IHBhdGgucmVwbGFjZSgnLycsICI6OiIpOwoKICAgIGlmIG1vZHVsZV9wYXRoLmlzX2VtcHR5KCkgewogICAgICAgIFNvbWUocHJlZml4LnRvX3N0cmluZygpKQogICAgfSBlbHNlIHsKICAgICAgICBTb21lKGZvcm1hdCEoInt9Ojp7fSIsIHByZWZpeCwgbW9kdWxlX3BhdGgpKQogICAgfQp9CgojW2NmZyh0ZXN0KV0KbW9kIHRlc3RzIHsKICAgIHVzZSBzdXBlcjo6ZmlsZV9wYXRoX3RvX21vZHVsZV9wYXRoOwoKICAgICNbdGVzdF0KICAgIGZuIGZpbGVfcGF0aF90b19tb2R1bGVfcGF0aF9zdXBwb3J0c191bml4X2FuZF93aW5kb3dzX3NlcGFyYXRvcnMoKSB7CiAgICAgICAgYXNzZXJ0X2VxISgKICAgICAgICAgICAgZmlsZV9wYXRoX3RvX21vZHVsZV9wYXRoKCJzcmMvZGF0YXR5cGUvbmFtZWQucnMiKSwKICAgICAgICAgICAgU29tZSgiY3JhdGU6OmRhdGF0eXBlOjpuYW1lZCIudG9fc3RyaW5nKCkpCiAgICAgICAgKTsKICAgICAgICBhc3NlcnRfZXEhKAogICAgICAgICAgICBmaWxlX3BhdGhfdG9fbW9kdWxlX3BhdGgoInNyY1xcZGF0YXR5cGVcXG5hbWVkLnJzIiksCiAgICAgICAgICAgIFNvbWUoImNyYXRlOjpkYXRhdHlwZTo6bmFtZWQiLnRvX3N0cmluZygpKQogICAgICAgICk7CiAgICAgICAgYXNzZXJ0X2VxISgKICAgICAgICAgICAgZmlsZV9wYXRoX3RvX21vZHVsZV9wYXRoKCJ0ZXN0cy90ZXN0cy90eXBlcy5ycyIpLAogICAgICAgICAgICBTb21lKCJ0ZXN0czo6dGVzdHM6OnR5cGVzIi50b19zdHJpbmcoKSkKICAgICAgICApOwogICAgICAgIGFzc2VydF9lcSEoCiAgICAgICAgICAgIGZpbGVfcGF0aF90b19tb2R1bGVfcGF0aCgidGVzdHNcXHRlc3RzXFx0eXBlcy5ycyIpLAogICAgICAgICAgICBTb21lKCJ0ZXN0czo6dGVzdHM6OnR5cGVzIi50b19zdHJpbmcoKSkKICAgICAgICApOwogICAgfQp9Cg=="

mkdir -p "$LOG_DIR"
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"
: > "$RESULTS"
rm -f "$OUTPUT" "$REPORT" "$REWARD"

write_failure() {
    reason="$1"
    python3 - "$reason" "$REPORT" "$OUTPUT" "$REWARD" <<'PY'
import json
import sys

reason, report_path, output_path, reward_path = sys.argv[1:]
payload = {
    "success": False,
    "infrastructure_error": reason,
    "raw_exit_code": 2,
    "reward": 0.0,
}
for path, value in ((report_path, payload), (output_path, {"results": []})):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
with open(reward_path, "w", encoding="utf-8") as handle:
    handle.write("0.0\n")
PY
    exit 2
}

ensure_reward() {
    if [ ! -f "$REWARD" ]; then
        printf '0.0\n' > "$REWARD"
    fi
}
trap ensure_reward EXIT

[ -f "$CONFIG" ] || write_failure "missing config.json"
[ -f "$TEST_PATCH" ] || write_failure "missing tests.patch"

WORKSPACE=""
if [ -n "${SENTINEL_WORKSPACE:-}" ] && [ -f "$SENTINEL_WORKSPACE/Cargo.toml" ]; then
    WORKSPACE="$SENTINEL_WORKSPACE"
else
    for candidate in /testbed /workspace /app; do
        if [ -f "$candidate/Cargo.toml" ] && [ -d "$candidate/specta" ]; then
            WORKSPACE="$candidate"
            break
        fi
    done
fi
[ -n "$WORKSPACE" ] || write_failure "could not resolve the agent workspace"
cd "$WORKSPACE" || write_failure "could not enter the agent workspace"

# Ignore solver-controlled Cargo wrappers/configuration. The task does not need
# a repository-local Cargo configuration.
if [ -e "$WORKSPACE/.cargo" ]; then
    mv "$WORKSPACE/.cargo" "$STATE_DIR/agent-cargo-config"
fi
unset RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER CARGO_BUILD_RUSTC CARGO_BUILD_RUSTC_WRAPPER
export CARGO_NET_OFFLINE=true

CARGO_BIN="${SENTINEL_CARGO:-}"
if [ -z "$CARGO_BIN" ]; then
    CARGO_BIN="$(command -v cargo 2>/dev/null || true)"
fi
[ -x "$CARGO_BIN" ] || write_failure "cargo is unavailable"

# Restore the genuine pass-to-pass source from a verifier-owned base snapshot,
# independent of runtime Git metadata, then add a completion marker to its
# existing regression test.
mkdir -p "$(dirname "$P2P_REL")"
printf '%s' "$P2P_SNAPSHOT_B64" | base64 -d > "$STATE_DIR/named.rs.base" ||
    write_failure "could not decode the pass-to-pass snapshot"
printf '%s  %s\n' "$P2P_SHA" "$STATE_DIR/named.rs.base" | sha256sum -c - >/dev/null 2>&1 ||
    write_failure "pass-to-pass snapshot integrity failure"
install -m 0644 "$STATE_DIR/named.rs.base" "$P2P_REL"

if ! patch -p1 --forward >"$STATE_DIR/p2p-wrapper.log" 2>&1 <<'P2P_PATCH'
diff --git a/specta/src/datatype/named.rs b/specta/src/datatype/named.rs
--- a/specta/src/datatype/named.rs
+++ b/specta/src/datatype/named.rs
@@ -386,5 +386,11 @@ mod tests {
             file_path_to_module_path("tests\\tests\\types.rs"),
             Some("tests::tests::types".to_string())
         );
+        let path = std::env::var("SENTINEL_COMPLETION_PATH")
+            .expect("missing completion path");
+        let token = std::env::var("SENTINEL_COMPLETION_TOKEN")
+            .expect("missing completion token");
+        std::fs::write(path, format!("datatype::named::tests::file_path_to_module_path_supports_unix_and_windows_separators:{token}"))
+            .expect("write completion token");
     }
 }
P2P_PATCH
then
    write_failure "could not install the pass-to-pass completion wrapper"
fi

# The hidden test path may have been independently created by a solver. Remove
# that exact verifier-owned destination before applying the canonical patch.
rm -f "$F2P_REL"
if command -v git >/dev/null 2>&1 &&
   git -c safe.directory="$WORKSPACE" apply --check "$TEST_PATCH" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"; then
    git -c safe.directory="$WORKSPACE" apply "$TEST_PATCH" >>"$STDOUT_LOG" 2>>"$STDERR_LOG" ||
        write_failure "tests.patch failed after a successful check"
elif patch -p1 --forward < "$TEST_PATCH" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"; then
    :
else
    write_failure "tests.patch did not apply"
fi
[ -f "$F2P_REL" ] || write_failure "the verifier-owned test file is missing"

# Build once before exposing per-test tokens. A successful process exit without
# the selected test's random completion record never counts as a pass.
timeout 180 "$CARGO_BIN" test --offline --locked -p specta-tags     --test sentinel_transform_contract --no-run >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
PREBUILD_RC=$?
if [ "$PREBUILD_RC" -ne 0 ]; then
    printf 'oracle test target prebuild exited %s\n' "$PREBUILD_RC" >>"$STDERR_LOG"
fi

readarray -t F2P_TESTS < <(python3 - "$CONFIG" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    config = json.load(handle)
for name in config["grading"]["fail_to_pass"]:
    print(name)
PY
)
readarray -t P2P_TESTS < <(python3 - "$CONFIG" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    config = json.load(handle)
for name in config["grading"]["pass_to_pass"]:
    print(name)
PY
)

run_one() {
    kind="$1"
    name="$2"
    completion="$STATE_DIR/completion"
    token="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
    rm -f "$completion"
    printf '\n[%s] %s\n' "$kind" "$name" >>"$STDOUT_LOG"

    if [ "$kind" = "fail_to_pass" ]; then
        env SENTINEL_COMPLETION_PATH="$completion" SENTINEL_COMPLETION_TOKEN="$token" \
            SENTINEL_EXPECTED_TEST="$name" timeout 8 "$CARGO_BIN" test --offline \
            --locked -p specta-tags --test sentinel_transform_contract "$name" \
            -- --exact --nocapture >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
        rc=$?
    else
        # The injected test directory alone matches the workspace's specta-*
        # glob on NOP. Hide that manifest-less directory while the independent
        # upstream regression test runs, then restore it for reporting.
        tag_hold="$WORKSPACE/.sentinel-specta-tags-hold"
        [ ! -e "$tag_hold" ] || write_failure "pass-to-pass hold path collision"
        mv "$WORKSPACE/specta-tags" "$tag_hold" ||
            write_failure "could not isolate specta-tags for pass-to-pass"
        env SENTINEL_COMPLETION_PATH="$completion" SENTINEL_COMPLETION_TOKEN="$token" \
            timeout 30 "$CARGO_BIN" test --offline --locked -p specta --lib \
            "$name" -- --exact --nocapture >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
        rc=$?
        mv "$tag_hold" "$WORKSPACE/specta-tags" ||
            write_failure "could not restore specta-tags after pass-to-pass"
    fi

    expected="$name:$token"
    actual=""
    if [ -f "$completion" ]; then
        actual="$(cat "$completion")"
    fi
    if [ "$rc" -eq 0 ] && [ "$actual" = "$expected" ]; then
        status="PASSED"
    else
        status="FAILED"
    fi
    printf '%s\t%s\t%s\t%s\n' "$kind" "$name" "$status" "$rc" >>"$RESULTS"
}

for name in "${F2P_TESTS[@]}"; do
    run_one fail_to_pass "$name"
done
for name in "${P2P_TESTS[@]}"; do
    run_one pass_to_pass "$name"
done

python3 - "$CONFIG" "$RESULTS" "$OUTPUT" "$REPORT" "$REWARD" <<'PY'
import json
import sys
from collections import Counter

config_path, results_path, output_path, report_path, reward_path = sys.argv[1:]
with open(config_path, encoding="utf-8") as handle:
    config = json.load(handle)
grading = config["grading"]
expected_f2p = list(grading["fail_to_pass"])
expected_p2p = list(grading["pass_to_pass"])
expected = expected_f2p + expected_p2p

results = []
with open(results_path, encoding="utf-8") as handle:
    for line in handle:
        kind, name, status, raw = line.rstrip("\n").split("\t")
        results.append({
            "name": name,
            "status": status,
            "kind": kind,
            "raw_exit_code": int(raw),
            "source": "verifier_owned_process_status_and_completion_token",
        })

names = [item["name"] for item in results]
duplicates = sorted(name for name, count in Counter(names).items() if count != 1)
unexpected = sorted(set(names) - set(expected))
missing = sorted(set(expected) - set(names))
wrong_kind = sorted(
    item["name"]
    for item in results
    if (
        item["name"] in expected_f2p and item["kind"] != "fail_to_pass"
    ) or (
        item["name"] in expected_p2p and item["kind"] != "pass_to_pass"
    )
)
nonpassing = sorted(item["name"] for item in results if item["status"] != "PASSED")
success = not (duplicates or unexpected or missing or wrong_kind or nonpassing)
raw_exit_code = 0 if success else 1
reward = 1.0 if success else 0.0

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump({"results": results}, handle, indent=2, sort_keys=True)
    handle.write("\n")
with open(report_path, "w", encoding="utf-8") as handle:
    json.dump({
        "success": success,
        "raw_exit_code": raw_exit_code,
        "reward": reward,
        "expected_count": len(expected),
        "observed_count": len(results),
        "duplicates": duplicates,
        "unexpected": unexpected,
        "missing": missing,
        "wrong_kind": wrong_kind,
        "nonpassing": nonpassing,
    }, handle, indent=2, sort_keys=True)
    handle.write("\n")
with open(reward_path, "w", encoding="utf-8") as handle:
    handle.write(f"{reward:.1f}\n")
sys.exit(raw_exit_code)
PY
exit $?
