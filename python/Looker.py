import json

def i(n):
    return ''.join(['\t' for x in range(n)])


def serialize_kvs(kvs):
    return ''.join([(", %s=%s" % (key, value))
                    for key, value in kvs.items()])


def column(model, config):
    mapping = {
        'integer': "Integer",
        'string': "String",
        'datetime': "DateTime",
        'date': "Date",
        'boolean': "Boolean",
        'text': "Text"
    }
    args = {}
    args['primary_key'] = config['primary_key']
    foreign_key = ''
    related_assoc = [assoc for assoc in model['associations']
                     if assoc['foreign_key'] == config['name']]
    if config['foreign_key'] and len(related_assoc) > 0:
        related_assoc = related_assoc[0]
        foreign_key = ", ForeignKey('%s.%s')" % (
            related_assoc['foreign_table'], related_assoc['primary_key'])
    return i(1) + "%s = Column(%s%s%s)" % (config['name'], mapping[config['type']], foreign_key, serialize_kvs(args))


# def join_chain(config, assoc_config, current, target):
def find_primary_assoc(model, assoc_config):
    if assoc_config['through']:
        return find_primary_assoc(model, [assoc for assoc in model['associations'] if assoc['name'] == assoc_config['through']][0])
    else:
        return assoc_config


def join_condition(assoc_type, model_1, key_1, model_2, key_2):
    if assoc_type == 'has_many':
        return "%s.%s == %s.%s" % (model_1, key_1, model_2, key_2)
    else:
        return "%s.%s == %s.%s" % (model_1, key_2, model_2, key_1)


def secondary_chain(model, assoc_config):
    acc = ""

    model_1 = assoc_config['joins']
    key_1 = assoc_config['foreign_key']
    key_2 = assoc_config['primary_key']

    direction = assoc_config['type']
    next_assoc = [assoc for assoc in model['associations']
                  if assoc['name'] == assoc_config['through']][0]

    model_2 = next_assoc['joins']

    acc += "join(%s, %s, " % (model_1, model_2)
    acc += join_condition(direction, model_1, key_1, model_2, key_2)
    acc += ')'

    while next_assoc['through']:
        model_1 = next_assoc['joins']
        key_1 = next_assoc['foreign_key']
        key_2 = next_assoc['primary_key']
        next_assoc = [assoc for assoc in model['associations']
                      if assoc['name'] == next_assoc['through']][0]

        model_2 = next_assoc['joins']

        acc += ".join(%s, " % model_2
        acc += join_condition(direction, model_1, key_1, model_2, key_2)
        acc += ')'

    return "'%s'" % acc


def association(models, model, assoc_config):
    args = {}

    if assoc_config['type'] == 'has_one':
        args['uselist'] = False
    if assoc_config['inverse_of']:
        args['back_populates'] = "'%s'" % assoc_config['inverse_of']
    if assoc_config['through']:
        primary_assoc = find_primary_assoc(model, assoc_config)
        args['primaryjoin'] = "'%s'" % join_condition(
            assoc_config['type'], primary_assoc['joins'], primary_assoc['foreign_key'], model['name'], primary_assoc['primary_key'])

        args['secondary'] = secondary_chain(model, assoc_config)

    return i(1) + "%s = relationship('%s'%s)" % (assoc_config['name'], assoc_config['joins'], serialize_kvs(args))


def to_file(models, model_config):
    ret = []
    p = ret.append
    p("from .Base import Base")
    p("from sqlalchemy import Column, Integer, String, ForeignKey, Date, DateTime, Boolean, Text")
    p("from sqlalchemy.orm import relationship")
    p("")
    p("class %s(Base):" % model_config['name'])
    p(i(1) + "__tablename__ = '%s'" % model_config['table_name'])
    p("")

    ret.extend([column(model_config, col) for col in model_config['columns']])
    p("")

    ret.extend([association(models, model_config, col)
                for col in model_config['associations']])

    return (model_config['name'], ret)


def write_file(root_path, arg):
    name, lines = arg
    f = open("%s/%s.py" % (root_path, name), "w")
    [f.write(line + '\n') for line in lines]
    f.close()

def produce_models(root_path, data):
    [write_file(root_path, to_file(data, model)) for model in data]

    f = open("%s/__init__.py" % root_path, "w")
    [f.write("from .%s import %s\n" % (model['name'], model['name'])) for model in data]
    f.close()
