FROM python

WORKDIR /var/data
CMD python -m http.server
