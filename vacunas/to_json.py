import sys
import csv
import json

class Data:
    name_to_codes = {}

    def load_iso_codes(self):
        with open("codes_spain.csv") as code_file:
            csv_reader = csv.DictReader(code_file)
            for row in csv_reader:
                self.name_to_codes[row["name"]] = row

    def new_element(self, date, ccaa_name):
        codes = self.name_to_codes[ccaa_name]
        element = {}
        element['date'] = date
        element["iso_code"] = codes["iso3611-2"]
        element["nuts2"] = codes["NUTS2"]
        element["name"] = ccaa_name
        element["supplier"] = "Unknown"
        return element

def create_json(date, lines, output_dir):
    administered = []
    delivered = []
    vaccinated = []
    suppliers = [(1, "Pfizer/BioNTech"),
                 (2, "Moderna"),
                 (3, "AstraZeneca/Oxford")]
    csv_reader = csv.reader(lines)
    data = Data()
    data.load_iso_codes()
    for row in csv_reader:
        element = data.new_element(date, row[0])
        element["administered"] = int(row[-2])
        administered.append(element)
        element = data.new_element(date, row[0])
        element["vaccinated"] = int(row[-1])
        element["supplier"] = suppliers[0][1]
        vaccinated.append(element)
        for column, supplier in suppliers:
            element = data.new_element(date, row[0])
            element["delivered"] = int(row[column])
            element["supplier"] = supplier
            delivered.append(element)
    for (name, data_list) in [("administered", administered),
                              ("delivered", delivered),
                              ("vaccinated", vaccinated)]:
        output_file = output_dir + date + "_" + name
        write_json(output_file + ".json", data_list)
        write_csv(output_file + ".csv", data_list)

def write_json(file_name, content):
    with open(file_name, "w", encoding="utf8") as output_file:
        json.dump(content, output_file, ensure_ascii=False, indent=4)

def write_csv(file_name, content):
    with open(file_name, "w", encoding="utf-8", newline="") as output_file:
        csv_writer = csv.DictWriter(output_file, fieldnames=content[0])
        csv_writer.writeheader()
        csv_writer.writerows(content)

def parseArgs(args):
    date = sys.argv[1]
    lines = None
    if sys.argv[2] == "-":
        # read lines from stdin
        lines = sys.stdin.readlines()
    else:
        with open(sys.argv[2]) as input_file:
            lines = input_file.readlines()
    output_dir = "./" if len(sys.argv) == 3 else sys.argv[3]
    if not output_dir.endswith("/"):
        output_dir += "/"
    return date, lines, output_dir

if len(sys.argv) > 2:
    date, lines, output_dir = parseArgs(sys.argv)
    create_json(date, lines, output_dir)