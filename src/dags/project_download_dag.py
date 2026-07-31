from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.decorators import dag

import pendulum
import boto3

AWS_ACCESS_KEY_ID = "YCAJEiyNFq4wiOe_eMCMCXmQP"
AWS_SECRET_ACCESS_KEY = "YCP1e96y4QI8OmcB4Eaf4q0nMHwhmtvGbDTgBeqS"
FILE_NAME = 'group_log.csv'
DOWNLOAD_PATH = f'/data/{FILE_NAME}'
S3_KEY = 'group_log.csv'



bash_command_tmpl = """
head {{ params.file_path }}
"""

AWS_ACCESS_KEY_ID = "YCAJEiyNFq4wiOe_eMCMCXmQP"
AWS_SECRET_ACCESS_KEY = "YCP1e96y4QI8OmcB4Eaf4q0nMHwhmtvGbDTgBeqS"

def fetch_s3_file(bucket: str, key: str) -> str:
    session = boto3.session.Session()
    s3_client = session.client(
        service_name='s3',
        endpoint_url='https://storage.yandexcloud.net',
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )
    s3_client.download_file(
				Bucket=bucket, 
				Key=key, 
				Filename=f'/data/{key}'
)

@dag(schedule_interval=None, start_date=pendulum.parse('2026-07-30'))
def project_file_download_dag():
    get_file = PythonOperator(
        task_id='get_file',
        python_callable=fetch_s3_file,
        op_kwargs={
            'bucket': 'sprint6',
            'key': S3_KEY,
            'dest_path': DOWNLOAD_PATH,
        },
    )

    print_10_lines_of_file = BashOperator(
        task_id='print_10_lines_of_file',
        bash_command=bash_command_tmpl,
        params={'file_path': DOWNLOAD_PATH},
    )

    get_file >> print_10_lines_of_file

_ = project_file_download_dag()