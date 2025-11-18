from web.views import create_app

# Gunicorn necesita esta variable global
app = create_app()

if __name__ == '__main__':
    # solo se ejecuta cuando NO es gunicorn
    app.run(host='0.0.0.0', port=5000, debug=True)
