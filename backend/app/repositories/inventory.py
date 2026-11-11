import json
from contextlib import closing
from uuid import UUID

from app.core.database import connect

# Identifiers come only from this closed application list, never from HTTP input.
PROCEDURES = {'usp_Catalog_List', 'usp_Category_Create', 'usp_User_Get', 'usp_User_Create',
              'usp_Product_List', 'usp_Product_Save', 'usp_Product_Deactivate',
              'usp_Lot_List', 'usp_Movement_Register', 'usp_Movement_List',
              'usp_Dashboard', 'usp_Health'}


def execute(procedure: str, **params) -> list[list[dict]]:
    if procedure not in PROCEDURES:
        raise ValueError('Procedimiento no permitido')
    # Parameter names are supplied by Services, not by clients.
    command = 'EXEC dbo.' + procedure
    if params:
        command += ' ' + ','.join('@' + name + '=?' for name in params)
    values = [str(v) if isinstance(v, UUID) else v for v in params.values()]
    with closing(connect()) as connection:
        cursor = connection.cursor()
        cursor.execute(command, values)
        sets = []
        while True:
            if cursor.description:
                names = [column[0] for column in cursor.description]
                rows = [dict(zip(names, row)) for row in cursor.fetchall()]
                for row in rows:
                    if 'lots' in row:
                        row['lots'] = json.loads(row['lots'] or '[]')
                sets.append(rows)
            if not cursor.nextset():
                break
        return sets


def rows(procedure: str, **params) -> list[dict]:
    sets = execute(procedure, **params)
    return sets[0] if sets else []
