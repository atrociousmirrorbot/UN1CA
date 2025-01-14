import os
import pickle
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.auth.transport.requests import Request

DRIVE_FOLDER_ID = "10EKDmw-L9HCGg5KRGP8BglY8RdTHp9gR"

def upload_in_drive(file_name, file_path):
    credentials = None
    token_path = os.path.join(os.getcwd(), 'token.pickle')

    if os.path.exists(token_path):
        with open(token_path, 'rb') as token:
            credentials = pickle.load(token)

    if not credentials or not credentials.valid:
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
        else:
            raise Exception("No valid credentials available. You need to obtain new OAuth tokens.")

    drive_service = build('drive', 'v3', credentials=credentials)
    file_metadata = {'name': file_name, 'parents': [DRIVE_FOLDER_ID]}
    media_body = MediaFileUpload(file_path, mimetype='application/octet-stream', resumable=True)
    uploaded_file = drive_service.files().create(body=file_metadata, media_body=media_body, supportsAllDrives=True, fields='id').execute()
    print(f'File uploaded. File ID is: https://drive.google.com/file/d/{uploaded_file.get("id")}')


def upload_all_md5_files(folder_path):
    for file_name in os.listdir(folder_path):
        if file_name.endswith('.md5'):
            file_path = os.path.join(folder_path, file_name)
            upload_in_drive(file_name, file_path)

upload_all_md5_files("/home/runner/work/UN1CA/UN1CA/out")
