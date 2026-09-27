# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
with open('api/views.py', 'r') as f:
    c = f.read()

c = c.replace("""        if not post:
            return Response({'react_count': 1, 'is_reacted': True}, status=status.HTTP_200_OK)""", """        if not post:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)""")

c = c.replace("""            if not created:
                reaction.delete()
                is_reacted = False""", """            if not created:
                is_reacted = True""")

with open('api/views.py', 'w') as f:
    f.write(c)
