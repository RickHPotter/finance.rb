const isEmpty = (value) => {
  return value === "" || value === null || value === undefined
}

const isPresent = (value) => {
  return !isEmpty(value)
}

const sleep = (fn, time = 0) => {
  return new Promise((resolve) => setTimeout(resolve, time))
    .then(fn)
}

export { isEmpty, isPresent, sleep }
