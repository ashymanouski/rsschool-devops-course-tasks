import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'code'))

from main import app

def test_hello_endpoint():
    """Test that the hello endpoint returns the expected response."""
    with app.test_client() as client:
        response = client.get('/')
        assert response.status_code == 200
        assert b'Hello, World!' in response.data

def test_hello_content():
    """Test that the hello endpoint returns the correct content."""
    with app.test_client() as client:
        response = client.get('/')
        assert response.get_data(as_text=True) == 'Hello, World!' 