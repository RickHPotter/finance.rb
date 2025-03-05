const is_empty = (value) => {
  return value === "" || value === null || value === undefined
}

const is_present = (value) => {
  return !is_empty(value)
}

const sleep = (fn, time = 0) => {
  return new Promise((resolve) => setTimeout(resolve, time))
    .then(fn)
}

export { is_empty, is_present, sleep }
